;; Crystal Nexus Exchange - Quantum Storage Protocol
;; A sophisticated digital resource allocation system with temporal constraints

;; Core system parameters
(define-constant PROTOCOL_SUPERVISOR tx-sender)
(define-constant ERR_PERMISSION_DENIED (err u100))
(define-constant ERR_NO_CRYSTAL (err u101))
(define-constant ERR_ALREADY_PROCESSED (err u102))
(define-constant ERR_TRANSMISSION_FAILED (err u103))
(define-constant ERR_INVALID_IDENTIFIER (err u104))
(define-constant ERR_INVALID_QUANTITY (err u105))
(define-constant ERR_INVALID_ORIGINATOR (err u106))
(define-constant ERR_CRYSTAL_DECAYED (err u107))
(define-constant CRYSTAL_STABILITY_PERIOD u1008) ;; ~7 days of stability

;; Crystal lattice storage framework
(define-map CrystalLattice
  { crystal-id: uint }
  {
    originator: principal,
    beneficiary: principal,
    wavelength: uint,
    energy: uint,
    lattice-state: (string-ascii 10),
    genesis-block: uint,
    decay-block: uint
  }
)


;; Tracking the highest crystal identifier
(define-data-var latest-crystal-id uint u0)

;; Utility functions for system integrity
(define-private (valid-beneficiary? (beneficiary principal))
  (and 
    (not (is-eq beneficiary tx-sender))
    (not (is-eq beneficiary (as-contract tx-sender)))
  )
)

(define-private (valid-crystal-id? (crystal-id uint))
  (<= crystal-id (var-get latest-crystal-id))
)

;; Protocol interaction functions

;; Complete transmission of crystal energy to beneficiary
(define-public (finalize-energy-transmission (crystal-id uint))
  (begin
    (asserts! (valid-crystal-id? crystal-id) ERR_INVALID_IDENTIFIER)
    (let
      (
        (crystal-data (unwrap! (map-get? CrystalLattice { crystal-id: crystal-id }) ERR_NO_CRYSTAL))
        (beneficiary (get beneficiary crystal-data))
        (energy (get energy crystal-data))
        (wavelength (get wavelength crystal-data))
      )
      (asserts! (or (is-eq tx-sender PROTOCOL_SUPERVISOR) (is-eq tx-sender (get originator crystal-data))) ERR_PERMISSION_DENIED)
      (asserts! (is-eq (get lattice-state crystal-data) "stabilizing") ERR_ALREADY_PROCESSED)
      (asserts! (<= block-height (get decay-block crystal-data)) ERR_CRYSTAL_DECAYED)
      (match (as-contract (stx-transfer? energy tx-sender beneficiary))
        success
          (begin
            (print {action: "crystal_transmitted", crystal-id: crystal-id, beneficiary: beneficiary, wavelength: wavelength, energy: energy})
            (ok true)
          )
        error ERR_TRANSMISSION_FAILED
      )
    )
  )
)

;; Redirect crystal energy to originator
(define-public (revert-crystal-energy (crystal-id uint))
  (begin
    (asserts! (valid-crystal-id? crystal-id) ERR_INVALID_IDENTIFIER)
    (let
      (
        (crystal-data (unwrap! (map-get? CrystalLattice { crystal-id: crystal-id }) ERR_NO_CRYSTAL))
        (originator (get originator crystal-data))
        (energy (get energy crystal-data))
      )
      (asserts! (is-eq tx-sender PROTOCOL_SUPERVISOR) ERR_PERMISSION_DENIED)
      (asserts! (is-eq (get lattice-state crystal-data) "stabilizing") ERR_ALREADY_PROCESSED)
      (match (as-contract (stx-transfer? energy tx-sender originator))
        success
          (begin
            (map-set CrystalLattice
              { crystal-id: crystal-id }
              (merge crystal-data { lattice-state: "reverted" })
            )
            (print {action: "energy_reverted", crystal-id: crystal-id, originator: originator, energy: energy})
            (ok true)
          )
        error ERR_TRANSMISSION_FAILED
      )
    )
  )
)
