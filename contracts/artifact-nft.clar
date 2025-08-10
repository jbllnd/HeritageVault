;; HeritageVault Artifact NFT Contract
;; Clarity v2
;; Manages NFTs for cultural artifact digital twins with provenance and metadata

(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-ZERO-ADDRESS u101)
(define-constant ERR-NFT-NOT-FOUND u102)
(define-constant ERR-NOT-OWNER u103)
(define-constant ERR-PAUSED u104)
(define-constant ERR-INVALID-METADATA u105)
(define-constant ERR-NOT-VERIFIED u106)

;; Contract metadata
(define-constant CONTRACT-NAME "HeritageVault Artifact NFT")
(define-constant MAX-NFTS u1000000) ;; Max 1M artifacts

;; Admin and contract state
(define-data-var admin principal tx-sender)
(define-data-var paused bool false)
(define-data-var total-nfts uint u0)
(define-data-var oracle principal 'SP000000000000000000002Q6VF78) ;; Placeholder for oracle

;; NFT data
(define-map nfts uint { owner: principal, metadata-uri: (string-ascii 256), verified: bool })
(define-map provenance uint (list 100 { owner: principal, timestamp: uint }))

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

;; Set oracle principal
(define-public (set-oracle (new-oracle principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (is-eq new-oracle 'SP000000000000000000002Q6VF78)) (err ERR-ZERO-ADDRESS))
    (var-set oracle new-oracle)
    (ok true)
  )
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (is-eq new-admin 'SP000000000000000000002Q6VF78)) (err ERR-ZERO-ADDRESS))
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

;; Mint new NFT for artifact
(define-public (mint-artifact (recipient principal) (metadata-uri (string-ascii 256)) (artifact-id uint))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (is-eq recipient 'SP000000000000000000002Q6VF78)) (err ERR-ZERO-ADDRESS))
    (asserts! (> (len metadata-uri) u0) (err ERR-INVALID-METADATA))
    (asserts! (< (var-get total-nfts) MAX-NFTS) (err ERR-MAX-SUPPLY-REACHED))
    (let ((token-id (+ (var-get total-nfts) u1)))
      (map-set nfts token-id { owner: recipient, metadata-uri: metadata-uri, verified: false })
      (map-set provenance token-id (list { owner: recipient, timestamp: block-height }))
      (var-set total-nfts token-id)
      (try! (emit-event "nft-minted" token-id metadata-uri))
      (ok token-id)
    )
  )
)

;; Verify artifact by oracle
(define-public (verify-artifact (token-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get oracle)) (err ERR-NOT-AUTHORIZED))
    (match (map-get? nfts token-id)
      nft
      (begin
        (map-set nfts token-id (merge nft { verified: true }))
        (try! (emit-event "nft-verified" token-id ""))
        (ok true)
      )
      (err ERR-NFT-NOT-FOUND)
    )
  )
)

;; Update metadata with DAO approval
(define-public (update-metadata (token-id uint) (new-metadata-uri (string-ascii 256)) (dao principal))
  (begin
    (asserts! (is-eq tx-sender dao) (err ERR-NOT-AUTHORIZED))
    (asserts! (> (len new-metadata-uri) u0) (err ERR-INVALID-METADATA))
    (match (map-get? nfts token-id)
      nft
      (begin
        (asserts! (get verified nft) (err ERR-NOT-VERIFIED))
        (map-set nfts token-id (merge nft { metadata-uri: new-metadata-uri }))
        (try! (emit-event "metadata-updated" token-id new-metadata-uri))
        (ok true)
      )
      (err ERR-NFT-NOT-FOUND)
    )
  )
)

;; Transfer NFT
(define-public (transfer-artifact (token-id uint) (new-owner principal))
  (begin
    (ensure-not-paused)
    (asserts! (not (is-eq new-owner 'SP000000000000000000002Q6VF78)) (err ERR-ZERO-ADDRESS))
    (match (map-get? nfts token-id)
      nft
      (begin
        (asserts! (is-eq (get owner nft) tx-sender) (err ERR-NOT-OWNER))
        (asserts! (get verified nft) (err ERR-NOT-VERIFIED))
        (map-set nfts token-id (merge nft { owner: new-owner }))
        (map-insert provenance token-id
          (cons { owner: new-owner, timestamp: block-height }
            (unwrap-panic (map-get? provenance token-id))))
        (try! (emit-event "nft-transferred" token-id (unwrap-panic (to-string new-owner))))
        (ok true)
      )
      (err ERR-NFT-NOT-FOUND)
    )
  )
)

;; Read-only: get NFT details
(define-read-only (get-nft (token-id uint))
  (match (map-get? nfts token-id)
    nft (ok nft)
    (err ERR-NFT-NOT-FOUND)
  )
)

;; Read-only: get provenance
(define-read-only (get-provenance (token-id uint))
  (match (map-get? provenance token-id)
    history (ok history)
    (err ERR-NFT-NOT-FOUND)
  )
)

;; Read-only: get total NFTs
(define-read-only (get-total-nfts)
  (ok (var-get total-nfts))
)

;; Read-only: get admin
(define-read-only (get-admin)
  (ok (var-get admin))
)

;; Read-only: get oracle
(define-read-only (get-oracle)
  (ok (var-get oracle))
)

;; Read-only: check if paused
(define-read-only (is-paused)
  (ok (var-get paused))
)