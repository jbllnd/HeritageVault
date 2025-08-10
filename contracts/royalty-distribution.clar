;; HeritageVault Royalty Distribution Contract
;; Clarity v2
;; Distributes royalties from NFT sales/loans to custodians and preservation treasury

(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-INVALID-NFT u101)
(define-constant ERR-INVALID-AMOUNT u102)
(define-constant ERR-PAUSED u103)
(define-constant ERR-INVALID-RULE u104)
(define-constant ERR-INSUFFICIENT-FUNDS u105)

;; Contract metadata
(define-constant CONTRACT-NAME "HeritageVault Royalty Distribution")
(define-constant MAX-TREASURY u1000000000) ;; Max 1B STX

;; Admin and contract state
(define-data-var admin principal tx-sender)
(define-data-var paused bool false)
(define-data-var dao-contract principal 'SP000000000000000000002Q6VF78)
(define-data-var nft-contract principal 'SP000000000000000000002Q6VF78)
(define-data-var treasury-balance uint u0)

;; Royalty rules
(define-map royalty-rules uint { custodian-share: uint, treasury-share: uint })
(define-map royalty-history uint (list 100 { recipient: principal, amount: uint, timestamp: uint }))

;; Events for off-chain indexing
(define-data-var last-event-id uint u0)
(define-map events uint { event-type: (string-ascii 32), token-id: uint, sender: principal, data: (string-ascii 256) })

;; Private helper: is-admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Private helper: ensure not paused
(define-private (ensure-not-paused)
  (asserts! (not (var-get paused)) (err ERR-PAUSED))
)

;; Private helper: emit event
(define-private (emit-event (event-type (string-ascii 32)) (token-id uint) (data (string-ascii 256)))
  (let ((event-id (+ (var-get last-event-id) u1)))
    (map-set events event-id { event-type: event-type, token-id: token-id, sender: tx-sender, data: data })
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

;; Set NFT contract
(define-public (set-nft-contract (new-nft principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (is-eq new-nft 'SP000000000000000000002Q6VF78)) (err ERR-NOT-AUTHORIZED))
    (var-set nft-contract new-nft)
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

;; Set royalty rules
(define-public (set-royalty-rules (token-id uint) (custodian-share uint) (treasury-share uint))
  (begin
    (asserts! (is-eq tx-sender (var-get dao-contract)) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-some (map-get? royalty-rules token-id)) (err ERR-INVALID-NFT))
    (asserts! (and (> custodian-share u0) (> treasury-share u0) (is-eq (+ custodian-share treasury-share) u100)) (err ERR-INVALID-RULE))
    (map-set royalty-rules token-id { custodian-share: custodian-share, treasury-share: treasury-share })
    (try! (emit-event "royalty-rules-set" token-id (unwrap-panic (to-string custodian-share))))
    (ok true)
  )
)

;; Distribute royalties
(define-public (distribute-royalties (token-id uint) (amount uint))
  (begin
    (ensure-not-paused)
    (asserts! (> amount u0) (err ERR-INVALID-AMOUNT))
    (match (map-get? royalty-rules token-id)
      rule
      (begin
        ;; Verify NFT exists (mocked for simplicity)
        (let (
          (custodian-amount (/ (* amount (get custodian-share rule)) u100))
          (treasury-amount (/ (* amount (get treasury-share rule)) u100))
        )
          (asserts! (<= (+ (var-get treasury-balance) treasury-amount) MAX-TREASURY) (err ERR-INSUFFICIENT-FUNDS))
          ;; Transfer to custodian (mocked)
          (var-set treasury-balance (+ (var-get treasury-balance) treasury-amount))
          (map-insert royalty-history token-id
            (cons { recipient: tx-sender, amount: custodian-amount, timestamp: block-height }
              (default-to (list) (map-get? royalty-history token-id))))
          (try! (emit-event "royalties-distributed" token-id (unwrap-panic (to-string amount))))
          (ok true)
        )
      )
      (err ERR-INVALID-NFT)
    )
  )
)

;; Withdraw treasury funds
(define-public (withdraw-treasury (recipient principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get dao-contract)) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (is-eq recipient 'SP000000000000000000002Q6VF78)) (err ERR-NOT-AUTHORIZED))
    (asserts! (> amount u0) (err ERR-INVALID-AMOUNT))
    (asserts! (<= amount (var-get treasury-balance)) (err ERR-INSUFFICIENT-FUNDS))
    (var-set treasury-balance (- (var-get treasury-balance) amount))
    ;; Transfer funds (mocked)
    (try! (emit-event "treasury-withdrawn" u0 (unwrap-panic (to-string amount))))
    (ok true)
  )
)

;; Read-only: get royalty rules
(define-read-only (get-royalty-rules (token-id uint))
  (match (map-get? royalty-rules token-id)
    rule (ok rule)
    (err ERR-INVALID-NFT)
  )
)

;; Read-only: get royalty history
(define-read-only (get-royalty-history (token-id uint))
  (match (map-get? royalty-history token-id)
    history (ok history)
    (err ERR-INVALID-NFT)
  )
)

;; Read-only: get treasury balance
(define-read-only (get-treasury-balance)
  (ok (var-get treasury-balance))
)

;; Read-only: get admin
(define-read-only (get-admin)
  (ok (var-get admin))
)

;; Read-only: check if paused
(define-read-only (is-paused)
  (ok (var-get paused))
)