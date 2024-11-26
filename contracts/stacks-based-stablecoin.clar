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

;; Add governance mechanism for parameter changes
(define-map governance-proposals 
  {
    proposal-id: uint,
    proposer: principal
  }
  {
    proposed-ratio: uint,
    proposed-fee: uint,
    votes-for: uint,
    votes-against: uint,
    executed: bool
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

;; Mint stablecoin
(define-public (mint (amount uint))
  (let (
    (sender tx-sender)
    (vault (get-vault-info sender))
    (current-collateral (get collateral vault))
    (current-debt (get debt vault))
    (stx-price (unwrap-panic (get-stx-price)))
    (required-collateral (/ (* amount (var-get collateralization-ratio)) stx-price))
  )
    (asserts! (>= (stx-get-balance sender) required-collateral) ERR_INSUFFICIENT_COLLATERAL)
    (try! (stx-transfer? required-collateral sender (as-contract tx-sender)))
    (try! (ft-mint? stacks-stablecoin amount sender))
    (map-set vaults sender
      (merge vault {
        collateral: (+ current-collateral required-collateral),
        debt: (+ current-debt amount),
        last-fee-update: (var-get current-block-height)
      }))
    (var-set total-supply (+ (var-get total-supply) amount))
    (ok true)))

;; Burn stablecoin
(define-public (burn (amount uint))
  (let (
    (sender tx-sender)
    (vault (get-vault-info sender))
    (current-collateral (get collateral vault))
    (current-debt (get debt vault))
    (stx-price (unwrap-panic (get-stx-price)))
    (collateral-to-release (/ (* amount stx-price) (var-get collateralization-ratio)))
  )
    (asserts! (<= amount current-debt) ERR_INSUFFICIENT_BALANCE)
    (try! (ft-burn? stacks-stablecoin amount sender))
    (try! (as-contract (stx-transfer? collateral-to-release tx-sender sender)))
    (map-set vaults sender
      (merge vault {
        collateral: (- current-collateral collateral-to-release),
        debt: (- current-debt amount),
        last-fee-update: (var-get current-block-height)
      }))
    (var-set total-supply (- (var-get total-supply) amount))
    (ok true)))

;; Add collateral
(define-public (add-collateral (amount uint))
  (let (
    (sender tx-sender)
    (vault (get-vault-info sender))
    (current-collateral (get collateral vault))
  )
    (try! (stx-transfer? amount sender (as-contract tx-sender)))
    (map-set vaults sender
      (merge vault {
        collateral: (+ current-collateral amount)
      }))
    (ok true)))

;; Remove collateral
(define-public (remove-collateral (amount uint))
  (let (
    (sender tx-sender)
    (vault (get-vault-info sender))
    (current-collateral (get collateral vault))
    (current-debt (get debt vault))
    (stx-price (unwrap-panic (get-stx-price)))
    (new-ratio (/ (* (- current-collateral amount) stx-price) current-debt))
  )
    (asserts! (>= new-ratio (var-get liquidation-ratio)) ERR_BELOW_LIQUIDATION_RATIO)
    (try! (as-contract (stx-transfer? amount tx-sender sender)))
    (map-set vaults sender
      (merge vault {
        collateral: (- current-collateral amount)
      }))
    (ok true)))
