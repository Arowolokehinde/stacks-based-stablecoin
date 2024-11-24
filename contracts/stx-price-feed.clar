
;; title: stx-price-feed

;; title: stx-price-oracle

;; STX Price Oracle
;; This contract provides the current price of STX in USD (scaled by 1e6)

;; Define the contract owner
(define-constant CONTRACT_OWNER tx-sender)

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_PRICE (err u101))

;; Current STX price in USD (scaled by 1e6)
(define-data-var stx-price uint u0)

;; Get the current STX price
(define-read-only (get-price)
  (ok (var-get stx-price)))

;; Update the STX price
;; Only the contract owner can update the price
(define-public (update-price (new-price uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> new-price u0) ERR_INVALID_PRICE)
    (ok (var-set stx-price new-price))))

;; Initialize the contract
(define-public (initialize (initial-price uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> initial-price u0) ERR_INVALID_PRICE)
    (var-set stx-price initial-price)
    (print "STX Price Oracle initialized successfully")
    (ok true)))