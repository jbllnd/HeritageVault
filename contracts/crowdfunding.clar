;; HeritageVault Crowdfunding Contract
;; Clarity v2
;; Manages tokenized crowdfunding for preservation projects with milestone-based payouts

(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-INVALID-PROJECT u101)
(define-constant ERR-MILESTONE-NOT-VERIFIED u102)
(define-constant ERR-ALREADY-FUNDED u103)
(define-constant ERR-INSUFFICIENT-FUNDS u104)
(define-constant ERR-PAUSED u105)
(define-constant ERR-INVALID-AMOUNT u106)

;; Contract metadata
(define-constant CONTRACT-NAME "HeritageVault Crowdfunding")
(define-constant MAX-PROJECTS u10000)

;; Admin and contract state
(define-data-var admin principal tx-sender)
(define-data-var paused bool false)
(define-data-var dao-contract principal 'SP000000000000000000002Q6VF78)
(define-data-var oracle principal 'SP000000000000000000002Q6VF78)

;; Project data
(define-map projects uint {
  proposal-id: uint,
  total-funded: uint,
  milestones: (list 10 { amount: uint, verified: bool }),
  active: bool
})
(define-map contributions uint { contributor: principal, amount: uint })
(define-data-var project-count uint u0)

;; Events for off-chain indexing
(define-data-var last-event-id uint u0)
(define-map events uint { event-type: (string-ascii 32), project-id: uint, sender: principal, data: (string-ascii 256) })

;; Private helper: is-admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Private helper: ensure not paused
(define-private (ensure-not-paused)
  (asserts! (not (var-get paused)) (err ERR-PAUSED))
)

;; Private helper: emit event
(define-private (emit-event (event-type (string-ascii 32)) (project-id uint) (data (string-ascii 256)))
  (let ((event-id (+ (var-get last-event-id) u1)))
    (map-set events event-id { event-type: event-type, project-id: project-id, sender: tx-sender, data: data })
    (var-set last-event-id event-id)
    (ok event-id)
  )
)

;; Set DAO contract
(define-public (set-dao-contract (new-dao principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (is-eq new-dao 'SP000000000000000000002Q6VF78)) (err ERR-NOT-AUTHORIZED))
    (var-set dao-contract new-dao)
    (ok true)
  )
)

;; Set oracle
(define-public (set-oracle (new-oracle principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (is-eq new-oracle 'SP000000000000000000002Q6VF78)) (err ERR-NOT-AUTHORIZED))
    (var-set oracle new-oracle)
    (ok true)
  )
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (is-eq new-admin 'SP000000000000000000002Q6VF78)) (err ERR-NOT-AUTHORIZED))
    (var-set admin new-admin)
    (try! (emit-event "admin-transferred" u0 (unwrap-panic (to-string new-admin))))
    (ok true)
  )
)

;; Pause/unpause contract
(define-public (set-paused (pause bool))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (var-set paused pause)
    (try! (emit-event "pause-toggled" u0 (if pause "paused" "unpaused")))
    (ok pause)
  )
)

;; Create a new project
(define-public (create-project (proposal-id uint) (milestones (list 10 uint)))
  (begin
    (asserts! (is-eq tx-sender (var-get dao-contract)) (err ERR-NOT-AUTHORIZED))
    (asserts! (> (len milestones) u0) (err ERR-INVALID-PROJECT))
    (asserts! (< (var-get project-count) MAX-PROJECTS) (err ERR-INVALID-PROJECT))
    (let ((project-id (+ (var-get project-count) u1)))
      (map-set projects project-id {
        proposal-id: proposal-id,
        total-funded: u0,
        milestones: (map (lambda (amount) { amount: amount, verified: false }) milestones),
        active: true
      })
      (var-set project-count project-id)
      (try! (emit-event "project-created" project-id (unwrap-panic (to-string proposal-id))))
      (ok project-id)
    )
  )
)

;; Fund a project
(define-public (fund-project (project-id uint) (amount uint))
  (begin
    (ensure-not-paused)
    (asserts! (> amount u0) (err ERR-INVALID-AMOUNT))
    (match (map-get? projects project-id)
      project
      (begin
        (asserts! (get active project) (err ERR-INVALID-PROJECT))
        ;; Transfer tokens (mocked for simplicity)
        (map-set contributions { project-id: project-id, contributor: tx-sender }
          { contributor: tx-sender, amount: (+ amount (default-to u0 (get amount (map-get? contributions { project-id: project-id, contributor: tx-sender })))) })
        (map-set projects project-id
          (merge project { total-funded: (+ (get total-funded project) amount) }))
        (try! (emit-event "project-funded" project-id (unwrap-panic (to-string amount))))
        (ok true)
      )
      (err ERR-INVALID-PROJECT)
    )
  )
)

;; Verify milestone by oracle
(define-public (verify-milestone (project-id uint) (milestone-index uint))
  (begin
    (asserts! (is-eq tx-sender (var-get oracle)) (err ERR-NOT-AUTHORIZED))
    (match (map-get? projects project-id)
      project
      (begin
        (asserts! (get active project) (err ERR-INVALID-PROJECT))
        (let ((milestones (get milestones project)))
          (asserts! (< milestone-index (len milestones)) (err ERR-MILESTONE-NOT-VERIFIED))
          (let ((milestone (unwrap-panic (element-at milestones milestone-index))))
            (asserts! (not (get verified milestone)) (err ERR-MILESTONE-NOT-VERIFIED))
            (map-set projects project-id
              (merge project {
                milestones: (map-insert milestones milestone-index
                  (merge milestone { verified: true }))
              }))
            (try! (emit-event "milestone-verified" project-id (unwrap-panic (to-string milestone-index))))
            (ok true)
          )
        )
      )
      (err ERR-INVALID-PROJECT)
    )
  )
)

;; Release funds for verified milestone
(define-public (release-funds (project-id uint) (milestone-index uint))
  (begin
    (ensure-not-paused)
    (match (map-get? projects project-id)
      project
      (begin
        (asserts! (get active project) (err ERR-INVALID-PROJECT))
        (let ((milestones (get milestones project)))
          (asserts! (< milestone-index (len milestones)) (err ERR-MILESTONE-NOT-VERIFIED))
          (let ((milestone (unwrap-panic (element-at milestones milestone-index))))
            (asserts! (get verified milestone) (err ERR-MILESTONE-NOT-VERIFIED))
            ;; Transfer funds (mocked for simplicity)
            (try! (emit-event "funds-released" project-id (unwrap-panic (to-string (get amount milestone)))))
            (ok true)
          )
        )
      )
      (err ERR-INVALID-PROJECT)
    )
  )
)

;; Refund contributors if project fails
(define-public (refund-contributors (project-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get dao-contract)) (err ERR-NOT-AUTHORIZED))
    (match (map-get? projects project-id)
      project
      (begin
        (asserts! (get active project) (err ERR-INVALID-PROJECT))
        (map-set projects project-id (merge project { active: false }))
        ;; Refund tokens (mocked for simplicity)
        (try! (emit-event "project-refunded" project-id ""))
        (ok true)
      )
      (err ERR-INVALID-PROJECT)
    )
  )
)

;; Read-only: get project
(define-read-only (get-project (project-id uint))
  (match (map-get? projects project-id)
    project (ok project)
    (err ERR-INVALID-PROJECT)
  )
)

;; Read-only: get contribution
(define-read-only (get-contribution (project-id uint) (contributor principal))
  (match (map-get? contributions { project-id: project-id, contributor: contributor })
    contribution (ok contribution)
    (err ERR-INVALID-PROJECT)
  )
)

;; Read-only: get project count
(define-read-only (get-project-count)
  (ok (var-get project-count))
)

;; Read-only: get admin
(define-read-only (get-admin)
  (ok (var-get admin))
)

;; Read-only: check if paused
(define-read-only (is-paused)
  (ok (var-get paused))
)