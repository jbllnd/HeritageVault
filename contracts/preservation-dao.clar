;; HeritageVault Preservation DAO Contract
;; Clarity v2
;; Manages governance for preservation projects via token-weighted voting

(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-INVALID-PROPOSAL u101)
(define-constant ERR-VOTING-CLOSED u102)
(define-constant ERR-QUORUM-NOT-MET u103)
(define-constant ERR-ALREADY-VOTED u104)
(define-constant ERR-INVALID-TOKEN u105)
(define-constant ERR-PAUSED u106)

;; Contract metadata
(define-constant CONTRACT-NAME "HeritageVault Preservation DAO")
(define-constant VOTING-PERIOD u1440) ;; ~10 days at 10 min/block
(define-constant QUORUM-PERCENT u50) ;; 50% of staked tokens required

;; Admin and contract state
(define-data-var admin principal tx-sender)
(define-data-var paused bool false)
(define-data-var token-contract principal 'SP000000000000000000002Q6VF78) ;; Placeholder for token contract

;; Proposal data
(define-map proposals uint {
  creator: principal,
  description: (string-ascii 256),
  funding-goal: uint,
  crowdfunding-contract: principal,
  votes-for: uint,
  votes-against: uint,
  end-block: uint,
  executed: bool
})
(define-map votes uint { voter: principal, amount: uint })
(define-data-var proposal-count uint u0)

;; Events for off-chain indexing
(define-data-var last-event-id uint u0)
(define-map events uint { event-type: (string-ascii 32), proposal-id: uint, sender: principal, data: (string-ascii 256) })

;; Private helper: is-admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Private helper: ensure not paused
(define-private (ensure-not-paused)
  (asserts! (not (var-get paused)) (err ERR-PAUSED))
)

;; Private helper: emit event
(define-private (emit-event (event-type (string-ascii 32)) (proposal-id uint) (data (string-ascii 256)))
  (let ((event-id (+ (var-get last-event-id) u1)))
    (map-set events event-id { event-type: event-type, proposal-id: proposal-id, sender: tx-sender, data: data })
    (var-set last-event-id event-id)
    (ok event-id)
  )
)

;; Set token contract
(define-public (set-token-contract (new-token principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (is-eq new-token 'SP000000000000000000002Q6VF78)) (err ERR-INVALID-TOKEN))
    (var-set token-contract new-token)
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

;; Create a new proposal
(define-public (create-proposal (description (string-ascii 256)) (funding-goal uint) (crowdfunding-contract principal))
  (begin
    (ensure-not-paused)
    (asserts! (> (len description) u0) (err ERR-INVALID-PROPOSAL))
    (asserts! (> funding-goal u0) (err ERR-INVALID-PROPOSAL))
    (asserts! (not (is-eq crowdfunding-contract 'SP000000000000000000002Q6VF78)) (err ERR-INVALID-PROPOSAL))
    (let ((proposal-id (+ (var-get proposal-count) u1)))
      (map-set proposals proposal-id {
        creator: tx-sender,
        description: description,
        funding-goal: funding-goal,
        crowdfunding-contract: crowdfunding-contract,
        votes-for: u0,
        votes-against: u0,
        end-block: (+ block-height VOTING-PERIOD),
        executed: false
      })
      (var-set proposal-count proposal-id)
      (try! (emit-event "proposal-created" proposal-id description))
      (ok proposal-id)
    )
  )
)

;; Vote on a proposal
(define-public (vote (proposal-id uint) (in-favor bool) (amount uint))
  (begin
    (ensure-not-paused)
    (match (map-get? proposals proposal-id)
      proposal
      (begin
        (asserts! (<= block-height (get end-block proposal)) (err ERR-VOTING-CLOSED))
        (asserts! (not (is-some (map-get? votes { voter: tx-sender, proposal-id: proposal-id }))) (err ERR-ALREADY-VOTED))
        (asserts! (> amount u0) (err ERR-INVALID-PROPOSAL))
        ;; Verify staked balance via token contract (mocked for simplicity)
        (map-set votes { voter: tx-sender, proposal-id: proposal-id } { amount: amount })
        (map-set proposals proposal-id
          (merge proposal {
            votes-for: (if in-favor (+ (get votes-for proposal) amount) (get votes-for proposal)),
            votes-against: (if in-favor (get votes-against proposal) (+ (get votes-against proposal) amount))
          }))
        (try! (emit-event "vote-cast" proposal-id (unwrap-panic (to-string amount))))
        (ok true)
      )
      (err ERR-INVALID-PROPOSAL)
    )
  )
)

;; Execute approved proposal
(define-public (execute-proposal (proposal-id uint))
  (begin
    (ensure-not-paused)
    (match (map-get? proposals proposal-id)
      proposal
      (begin
        (asserts! (> block-height (get end-block proposal)) (err ERR-VOTING-CLOSED))
        (asserts! (not (get executed proposal)) (err ERR-INVALID-PROPOSAL))
        (let ((total-votes (+ (get votes-for proposal) (get votes-against proposal))))
          (asserts! (>= (/ (* (get votes-for proposal) u100) total-votes) QUORUM-PERCENT) (err ERR-QUORUM-NOT-MET))
          (map-set proposals proposal-id (merge proposal { executed: true }))
          ;; Trigger crowdfunding contract (mocked for simplicity)
          (try! (emit-event "proposal-executed" proposal-id (get description proposal)))
          (ok true)
        )
      )
      (err ERR-INVALID-PROPOSAL)
    )
  )
)

;; Read-only: get proposal
(define-read-only (get-proposal (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal (ok proposal)
    (err ERR-INVALID-PROPOSAL)
  )
)

;; Read-only: get vote
(define-read-only (get-vote (proposal-id uint) (voter principal))
  (match (map-get? votes { voter: voter, proposal-id: proposal-id })
    vote (ok vote)
    (err ERR-INVALID-PROPOSAL)
  )
)

;; Read-only: get proposal count
(define-read-only (get-proposal-count)
  (ok (var-get proposal-count))
)

;; Read-only: get admin
(define-read-only (get-admin)
  (ok (var-get admin))
)

;; Read-only: check if paused
(define-read-only (is-paused)
  (ok (var-get paused))
)