;; title: stx-price-oracle

;; STX Price Oracle
;; This contract provides the current price of STX in USD (scaled by 1e6)

;; Define the contract owner
;; The contract owner has exclusive privileges to update the price.
(define-constant CONTRACT_OWNER tx-sender)

;; Error codes
;; ERR_UNAUTHORIZED: Raised if a non-owner attempts an unauthorized operation.
;; ERR_INVALID_PRICE: Raised if the provided price is invalid (<= 0).
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_PRICE (err u101))

;; Current STX price in USD (scaled by 1e6)
;; This variable stores the latest price of STX provided by the oracle.
(define-data-var stx-price uint u0)

;; Get the current STX price
;; Returns the latest STX/USD price stored in the contract.
(define-read-only (get-price)
  (ok (var-get stx-price)))

;; Update the STX price
;; Allows the contract owner to update the STX/USD price.
;; Ensures that the new price is valid and greater than zero.
(define-public (update-price (new-price uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> new-price u0) ERR_INVALID_PRICE)
    (ok (var-set stx-price new-price))))

;; Initialize the contract
;; Sets the initial STX price and is restricted to the contract owner.
(define-public (initialize (initial-price uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> initial-price u0) ERR_INVALID_PRICE)
    (var-set stx-price initial-price)
    (print "STX Price Oracle initialized successfully")
    (ok true)))
