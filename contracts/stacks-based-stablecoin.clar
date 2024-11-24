;; title: stacks-based-stablecoin

;; Stacks-Based Stablecoin
;; A collateralized stablecoin backed by STX tokens

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_BELOW_LIQUIDATION_RATIO (err u104))

;; Define the token
(define-fungible-token stacks-stablecoin)

;; Price feed contract
(define-constant PRICE_FEED_CONTRACT .stx-price-feed)

;; Collateralization ratio (150%)
(define-data-var collateralization-ratio uint u150)

;; Liquidation ratio (120%)
(define-data-var liquidation-ratio uint u120)

;; Stability fee (1%)
(define-data-var stability-fee uint u1)

;; Total supply
(define-data-var total-supply uint u0)

;; Block height tracking (for testing purposes)
(define-data-var current-block-height uint u0)

;; Get current block height
(define-read-only (get-current-block-height)
  (var-get current-block-height))

;; Set block height (only owner)
(define-public (set-block-height (new-height uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set current-block-height new-height)
    (ok true)))

;; Vault map
(define-map vaults
  principal
  {
    collateral: uint,
    debt: uint,
    last-fee-update: uint
  }
)

;; Get STX/USD price
(define-public (get-stx-price)
  (contract-call? PRICE_FEED_CONTRACT get-price))

;; Get vault info
(define-read-only (get-vault-info (user principal))
  (default-to
    { collateral: u0, debt: u0, last-fee-update: u0 }
    (map-get? vaults user)))

;; Calculate collateral ratio
(define-public (get-collateral-ratio (user principal))
  (let (
    (vault (get-vault-info user))
    (collateral (get collateral vault))
    (debt (get debt vault))
    (stx-price (unwrap-panic (get-stx-price)))
  )
  (ok (if (is-eq debt u0)
    u0
    (/ (* collateral stx-price) debt)))))
