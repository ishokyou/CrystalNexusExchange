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


;; Originator requests crystal dissolution
(define-public (dissolve-crystal (crystal-id uint))
  (begin
    (asserts! (valid-crystal-id? crystal-id) ERR_INVALID_IDENTIFIER)
    (let
      (
        (crystal-data (unwrap! (map-get? CrystalLattice { crystal-id: crystal-id }) ERR_NO_CRYSTAL))
        (originator (get originator crystal-data))
        (energy (get energy crystal-data))
      )
      (asserts! (is-eq tx-sender originator) ERR_PERMISSION_DENIED)
      (asserts! (is-eq (get lattice-state crystal-data) "stabilizing") ERR_ALREADY_PROCESSED)
      (asserts! (<= block-height (get decay-block crystal-data)) ERR_CRYSTAL_DECAYED)
      (match (as-contract (stx-transfer? energy tx-sender originator))
        success
          (begin
            (map-set CrystalLattice
              { crystal-id: crystal-id }
              (merge crystal-data { lattice-state: "dissolved" })
            )
            (print {action: "crystal_dissolved", crystal-id: crystal-id, originator: originator, energy: energy})
            (ok true)
          )
        error ERR_TRANSMISSION_FAILED
      )
    )
  )
)

;; Extend crystal stability period
(define-public (extend-crystal-stability (crystal-id uint) (additional-blocks uint))
  (begin
    (asserts! (valid-crystal-id? crystal-id) ERR_INVALID_IDENTIFIER)
    (asserts! (> additional-blocks u0) ERR_INVALID_QUANTITY)
    (asserts! (<= additional-blocks u1440) ERR_INVALID_QUANTITY) ;; Max ~10 days extension
    (let
      (
        (crystal-data (unwrap! (map-get? CrystalLattice { crystal-id: crystal-id }) ERR_NO_CRYSTAL))
        (originator (get originator crystal-data)) 
        (beneficiary (get beneficiary crystal-data))
        (current-decay (get decay-block crystal-data))
        (updated-decay (+ current-decay additional-blocks))
      )
      (asserts! (or (is-eq tx-sender originator) (is-eq tx-sender beneficiary) (is-eq tx-sender PROTOCOL_SUPERVISOR)) ERR_PERMISSION_DENIED)
      (asserts! (or (is-eq (get lattice-state crystal-data) "stabilizing") (is-eq (get lattice-state crystal-data) "acknowledged")) ERR_ALREADY_PROCESSED)
      (map-set CrystalLattice
        { crystal-id: crystal-id }
        (merge crystal-data { decay-block: updated-decay })
      )
      (print {action: "stability_extended", crystal-id: crystal-id, requester: tx-sender, new-decay-block: updated-decay})
      (ok true)
    )
  )
)

;; Reclaim decayed crystal energy
(define-public (reclaim-decayed-crystal (crystal-id uint))
  (begin
    (asserts! (valid-crystal-id? crystal-id) ERR_INVALID_IDENTIFIER)
    (let
      (
        (crystal-data (unwrap! (map-get? CrystalLattice { crystal-id: crystal-id }) ERR_NO_CRYSTAL))
        (originator (get originator crystal-data))
        (energy (get energy crystal-data))
        (decay-point (get decay-block crystal-data))
      )
      (asserts! (or (is-eq tx-sender originator) (is-eq tx-sender PROTOCOL_SUPERVISOR)) ERR_PERMISSION_DENIED)
      (asserts! (or (is-eq (get lattice-state crystal-data) "stabilizing") (is-eq (get lattice-state crystal-data) "acknowledged")) ERR_ALREADY_PROCESSED)
      (asserts! (> block-height decay-point) (err u108)) ;; Must be decayed
      (match (as-contract (stx-transfer? energy tx-sender originator))
        success
          (begin
            (map-set CrystalLattice
              { crystal-id: crystal-id }
              (merge crystal-data { lattice-state: "decayed" })
            )
            (print {action: "decayed_crystal_reclaimed", crystal-id: crystal-id, originator: originator, energy: energy})
            (ok true)
          )
        error ERR_TRANSMISSION_FAILED
      )
    )
  )
)

;; Request lattice anomaly investigation
(define-public (report-lattice-anomaly (crystal-id uint) (anomaly-description (string-ascii 50)))
  (begin
    (asserts! (valid-crystal-id? crystal-id) ERR_INVALID_IDENTIFIER)
    (let
      (
        (crystal-data (unwrap! (map-get? CrystalLattice { crystal-id: crystal-id }) ERR_NO_CRYSTAL))
        (originator (get originator crystal-data))
        (beneficiary (get beneficiary crystal-data))
      )
      (asserts! (or (is-eq tx-sender originator) (is-eq tx-sender beneficiary)) ERR_PERMISSION_DENIED)
      (asserts! (or (is-eq (get lattice-state crystal-data) "stabilizing") (is-eq (get lattice-state crystal-data) "acknowledged")) ERR_ALREADY_PROCESSED)
      (asserts! (<= block-height (get decay-block crystal-data)) ERR_CRYSTAL_DECAYED)
      (map-set CrystalLattice
        { crystal-id: crystal-id }
        (merge crystal-data { lattice-state: "anomalous" })
      )
      (print {action: "anomaly_reported", crystal-id: crystal-id, reporter: tx-sender, description: anomaly-description})
      (ok true)
    )
  )
)

;; Register quantum signature verification
(define-public (register-quantum-signature (crystal-id uint) (quantum-signature (buff 65)))
  (begin
    (asserts! (valid-crystal-id? crystal-id) ERR_INVALID_IDENTIFIER)
    (let
      (
        (crystal-data (unwrap! (map-get? CrystalLattice { crystal-id: crystal-id }) ERR_NO_CRYSTAL))
        (originator (get originator crystal-data))
        (beneficiary (get beneficiary crystal-data))
      )
      (asserts! (or (is-eq tx-sender originator) (is-eq tx-sender beneficiary)) ERR_PERMISSION_DENIED)
      (asserts! (or (is-eq (get lattice-state crystal-data) "stabilizing") (is-eq (get lattice-state crystal-data) "acknowledged")) ERR_ALREADY_PROCESSED)
      (print {action: "signature_registered", crystal-id: crystal-id, registrar: tx-sender, signature: quantum-signature})
      (ok true)
    )
  )
)

;; Resolve anomaly with quantum balancing
(define-public (balance-quantum-anomaly (crystal-id uint) (originator-ratio uint))
  (begin
    (asserts! (valid-crystal-id? crystal-id) ERR_INVALID_IDENTIFIER)
    (asserts! (is-eq tx-sender PROTOCOL_SUPERVISOR) ERR_PERMISSION_DENIED)
    (asserts! (<= originator-ratio u100) ERR_INVALID_QUANTITY) ;; Ratio must be 0-100
    (let
      (
        (crystal-data (unwrap! (map-get? CrystalLattice { crystal-id: crystal-id }) ERR_NO_CRYSTAL))
        (originator (get originator crystal-data))
        (beneficiary (get beneficiary crystal-data))
        (energy (get energy crystal-data))
        (originator-energy (/ (* energy originator-ratio) u100))
        (beneficiary-energy (- energy originator-energy))
      )
      (asserts! (is-eq (get lattice-state crystal-data) "anomalous") (err u112)) ;; Must be anomalous
      (asserts! (<= block-height (get decay-block crystal-data)) ERR_CRYSTAL_DECAYED)

      ;; Send originator's portion
      (unwrap! (as-contract (stx-transfer? originator-energy tx-sender originator)) ERR_TRANSMISSION_FAILED)

      ;; Send beneficiary's portion
      (unwrap! (as-contract (stx-transfer? beneficiary-energy tx-sender beneficiary)) ERR_TRANSMISSION_FAILED)

      (map-set CrystalLattice
        { crystal-id: crystal-id }
        (merge crystal-data { lattice-state: "balanced" })
      )
      (print {action: "anomaly_balanced", crystal-id: crystal-id, originator: originator, beneficiary: beneficiary, 
              originator-energy: originator-energy, beneficiary-energy: beneficiary-energy, originator-ratio: originator-ratio})
      (ok true)
    )
  )
)

;; Register emergency resonance point
(define-public (register-emergency-resonance (crystal-id uint) (resonance-point principal))
  (begin
    (asserts! (valid-crystal-id? crystal-id) ERR_INVALID_IDENTIFIER)
    (let
      (
        (crystal-data (unwrap! (map-get? CrystalLattice { crystal-id: crystal-id }) ERR_NO_CRYSTAL))
        (originator (get originator crystal-data))
      )
      (asserts! (is-eq tx-sender originator) ERR_PERMISSION_DENIED)
      (asserts! (not (is-eq resonance-point tx-sender)) (err u111)) ;; Resonance point must be different
      (asserts! (is-eq (get lattice-state crystal-data) "stabilizing") ERR_ALREADY_PROCESSED)
      (print {action: "resonance_registered", crystal-id: crystal-id, originator: originator, resonance: resonance-point})
      (ok true)
    )
  )
)

;; Register additional observer for high-energy crystals
(define-public (register-additional-observer (crystal-id uint) (observer principal))
  (begin
    (asserts! (valid-crystal-id? crystal-id) ERR_INVALID_IDENTIFIER)
    (let
      (
        (crystal-data (unwrap! (map-get? CrystalLattice { crystal-id: crystal-id }) ERR_NO_CRYSTAL))
        (originator (get originator crystal-data))
        (energy (get energy crystal-data))
      )
      ;; Only for high-energy crystals (> 1000 STX)
      (asserts! (> energy u1000) (err u120))
      (asserts! (or (is-eq tx-sender originator) (is-eq tx-sender PROTOCOL_SUPERVISOR)) ERR_PERMISSION_DENIED)
      (asserts! (is-eq (get lattice-state crystal-data) "stabilizing") ERR_ALREADY_PROCESSED)
      (print {action: "observer_registered", crystal-id: crystal-id, observer: observer, requester: tx-sender})
      (ok true)
    )
  )
)

