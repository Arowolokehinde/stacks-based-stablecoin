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

;; Liquidate undercollateralized position
(define-public (liquidate (user principal))
  (let (
    (vault (get-vault-info user))
    (collateral-ratio (unwrap-panic (get-collateral-ratio user)))
    (min-ratio (var-get liquidation-ratio))
  )
    (asserts! (< collateral-ratio min-ratio) ERR_UNAUTHORIZED)
    (let (
      (debt (get debt vault))
      (collateral (get collateral vault))
    )
      (try! (ft-burn? stacks-stablecoin debt tx-sender))
      (try! (as-contract (stx-transfer? collateral tx-sender tx-sender)))
      (map-delete vaults user)
      (var-set total-supply (- (var-get total-supply) debt))
      (ok true))))

;; Update stability fee
(define-public (update-stability-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set stability-fee new-fee)
    (ok true)))

;; Collect stability fee
(define-public (collect-stability-fee)
  (let (
    (sender tx-sender)
    (vault (get-vault-info sender))
    (debt (get debt vault))
    (last-fee-update (get last-fee-update vault))
    (blocks-passed (- (var-get current-block-height) last-fee-update))
    (fee-amount (/ (* debt (var-get stability-fee) blocks-passed) (* u100 u144))) ;; Assuming 144 blocks per day
  )
    (asserts! (> fee-amount u0) ERR_INVALID_AMOUNT)
    (try! (ft-mint? stacks-stablecoin fee-amount CONTRACT_OWNER))
    (map-set vaults sender
      (merge vault {
        debt: (+ debt fee-amount),
        last-fee-update: (var-get current-block-height)
      }))
    (var-set total-supply (+ (var-get total-supply) fee-amount))
    (ok true)))

;; Initialize the contract
(define-public (initialize (initial-stx-price uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (try! (ft-mint? stacks-stablecoin u0 CONTRACT_OWNER))
    (var-set current-block-height u0)
    (print "Stacks-Based Stablecoin initialized successfully")
    (ok true)))



;; Voting power tracking
(define-map voter-voting-power principal uint)

;; Implement oracle price update mechanism
(define-public (update-oracle-price (new-price uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (try! (contract-call? PRICE_FEED_CONTRACT update-price new-price))
    (ok true)))

;; Vote on governance proposal
(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
  (let (
    (sender tx-sender)
    (voting-power (default-to u0 (map-get? voter-voting-power sender)))
    (proposal (unwrap! 
      (map-get? governance-proposals 
        {proposal-id: proposal-id, proposer: CONTRACT_OWNER}) 
      ERR_UNAUTHORIZED))
  )
    (asserts! (not (get executed proposal)) ERR_UNAUTHORIZED)
    (if vote-for
      (map-set governance-proposals 
        {proposal-id: proposal-id, proposer: CONTRACT_OWNER}
        (merge proposal {votes-for: (+ (get votes-for proposal) voting-power)}))
      (map-set governance-proposals 
        {proposal-id: proposal-id, proposer: CONTRACT_OWNER}
        (merge proposal {votes-against: (+ (get votes-against proposal) voting-power)}))
    )
    (ok true)))

;; Execute governance proposal
(define-public (execute-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! 
      (map-get? governance-proposals 
        {proposal-id: proposal-id, proposer: CONTRACT_OWNER}) 
      ERR_UNAUTHORIZED))
  )
    (asserts! (not (get executed proposal)) ERR_UNAUTHORIZED)
    (asserts! (>= (get votes-for proposal) (/ (stx-get-balance CONTRACT_OWNER) u2)) ERR_UNAUTHORIZED)
    
    ;; Update parameters if proposal passes
    (var-set collateralization-ratio (get proposed-ratio proposal))
    (var-set stability-fee (get proposed-fee proposal))
    
    ;; Mark proposal as executed
    (map-set governance-proposals 
      {proposal-id: proposal-id, proposer: CONTRACT_OWNER}
      (merge proposal {executed: true}))
    
    (ok true)))

;; Implement reward mechanism for long-term stakers
(define-public (stake-voting-tokens (amount uint))
  (let (
    (sender tx-sender)
    (current-power (default-to u0 (map-get? voter-voting-power sender)))
  )
    (try! (stx-transfer? amount sender (as-contract tx-sender)))
    (map-set voter-voting-power sender (+ current-power amount))
    (ok true)))

;; Unstake voting tokens
(define-public (unstake-voting-tokens (amount uint))
  (let (
    (sender tx-sender)
    (current-power (unwrap! (map-get? voter-voting-power sender) ERR_INSUFFICIENT_BALANCE))
  )
    (asserts! (>= current-power amount) ERR_INSUFFICIENT_BALANCE)
    (try! (as-contract (stx-transfer? amount tx-sender sender)))
    (map-set voter-voting-power sender (- current-power amount))
    (ok true)))

;; Emergency pause mechanism
(define-data-var contract-paused bool false)

(define-public (toggle-contract-pause)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set contract-paused (not (var-get contract-paused)))
    (ok (var-get contract-paused))))

;; Add events for important actions
(define-map events
  {
    event-type: (string-ascii 32),
    user: principal,
    timestamp: uint
  }
  {
    details: (string-ascii 128)
  }
)

(define-private (log-event (event-type (string-ascii 32)) (user principal) (details (string-ascii 128)))
  (map-set events
    {
      event-type: event-type,
      user: user,
      timestamp: (var-get current-block-height)
    }
    {
      details: details
    }))
