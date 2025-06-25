;; Academic Research Council
;; Implements quadratic voting for research funding decisions where influence = sqrt(academic_credits)

;; Error codes
(define-constant ERR-UNAUTHORIZED-RESEARCHER (err u200))
(define-constant ERR-RESEARCH-PROPOSAL-MISSING (err u201))
(define-constant ERR-DUPLICATE-REVIEW (err u202))
(define-constant ERR-REVIEW-DEADLINE-PASSED (err u203))
(define-constant ERR-REVIEW-STILL-ONGOING (err u204))
(define-constant ERR-RESEARCH-INACTIVE (err u205))
(define-constant ERR-INSUFFICIENT-CREDITS (err u206))
(define-constant ERR-INVALID-RESEARCH-PROPOSAL (err u207))
(define-constant ERR-FUNDING-WINDOW-CLOSED (err u208))

;; Constants
(define-constant COUNCIL-CHAIR tx-sender)
(define-constant REVIEW-DURATION u2160) ;; blocks (~15 days)
(define-constant MIN-ACADEMIC-CREDITS u500) ;; minimum credits to submit research proposal
(define-constant FUNDING-PROCESSING-TIME u216) ;; blocks (~1.5 days)

;; Data Variables
(define-data-var research-proposal-id uint u0)

;; Academic credits tracking
(define-map academic-credits
  { researcher: principal }
  { credits: uint, last-evaluation: uint }
)

;; Research proposal states
(define-constant UNDER-REVIEW u0)
(define-constant REVIEW-ACTIVE u1)
(define-constant FUNDING-APPROVED u2)
(define-constant FUNDING-REJECTED u3)
(define-constant FUNDS-DISTRIBUTED u4)
(define-constant PROPOSAL-WITHDRAWN u5)

;; Data Maps
(define-map research-proposals
  { research-id: uint }
  {
    project-title: (string-ascii 100),
    research-abstract: (string-ascii 500),
    principal-investigator: principal,
    review-start: uint,
    review-end: uint,
    support-votes: uint,
    opposition-votes: uint,
    funding-status: uint,
    distribution-block: uint,
    grant-details: (optional { institution: principal, methodology: (string-ascii 50), budget-items: (list 10 uint) })
  }
)

(define-map peer-reviews
  { research-id: uint, reviewer: principal }
  {
    recommendation: bool, ;; true = approve funding, false = reject
    influence-weight: uint,
    review-timestamp: uint
  }
)

(define-map researcher-profiles
  { researcher: principal }
  {
    total-reviews-submitted: uint,
    research-proposals-led: uint,
    last-academic-activity: uint
  }
)

;; Helper Functions

;; Calculate square root using Newton's method
(define-private (calculate-sqrt (n uint))
  (if (is-eq n u0)
    u0
    (if (<= n u1)
      u1
      (let 
        (
          (estimate0 (/ n u2))
          (estimate1 (/ (+ estimate0 (/ n estimate0)) u2))
          (estimate2 (/ (+ estimate1 (/ n estimate1)) u2))
          (estimate3 (/ (+ estimate2 (/ n estimate2)) u2))
          (estimate4 (/ (+ estimate3 (/ n estimate3)) u2))
          (estimate5 (/ (+ estimate4 (/ n estimate4)) u2))
        )
        estimate5
      )
    )
  )
)

;; Get researcher's academic credits
(define-private (get-researcher-credits (researcher principal))
  (get credits 
    (default-to 
      { credits: u0, last-evaluation: u0 }
      (map-get? academic-credits { researcher: researcher })
    )
  )
)

;; Calculate academic influence based on quadratic formula
(define-private (determine-academic-influence (credit-balance uint))
  (calculate-sqrt credit-balance)
)

;; Verify research proposal exists
(define-private (research-proposal-exists (research-id uint))
  (is-some (map-get? research-proposals { research-id: research-id }))
)

;; Get current blockchain height
(define-private (current-block-height)
  block-height
)

;; Public Functions

;; Update academic credits (called by academic institutions or evaluators)
(define-public (update-academic-credits (researcher principal) (new-credits uint))
  (begin
    (map-set academic-credits
      { researcher: researcher }
      { credits: new-credits, last-evaluation: block-height }
    )
    (ok true)
  )
)

;; Batch update multiple researcher credits
(define-public (batch-credit-updates (credit-updates (list 100 { researcher: principal, credits: uint })))
  (begin
    (map process-credit-update credit-updates)
    (ok (len credit-updates))
  )
)

(define-private (process-credit-update (update { researcher: principal, credits: uint }))
  (map-set academic-credits
    { researcher: (get researcher update) }
    { credits: (get credits update), last-evaluation: block-height }
  )
)

;; Submit research proposal for funding
(define-public (submit-research-proposal 
  (project-title (string-ascii 100))
  (research-abstract (string-ascii 500))
  (grant-info (optional { institution: principal, methodology: (string-ascii 50), budget-items: (list 10 uint) }))
)
  (let 
    (
      (researcher-credits (get-researcher-credits tx-sender))
      (research-id (+ (var-get research-proposal-id) u1))
      (current-block (current-block-height))
    )
    ;; Check minimum academic credit requirement
    (asserts! (>= researcher-credits MIN-ACADEMIC-CREDITS) ERR-INSUFFICIENT-CREDITS)
    
    ;; Create research proposal
    (map-set research-proposals
      { research-id: research-id }
      {
        project-title: project-title,
        research-abstract: research-abstract,
        principal-investigator: tx-sender,
        review-start: current-block,
        review-end: (+ current-block REVIEW-DURATION),
        support-votes: u0,
        opposition-votes: u0,
        funding-status: REVIEW-ACTIVE,
        distribution-block: (+ current-block REVIEW-DURATION FUNDING-PROCESSING-TIME),
        grant-details: grant-info
      }
    )
    
    ;; Increment proposal counter
    (var-set research-proposal-id research-id)
    
    ;; Update researcher profile
    (map-set researcher-profiles
      { researcher: tx-sender }
      (merge 
        (default-to 
          { total-reviews-submitted: u0, research-proposals-led: u0, last-academic-activity: u0 }
          (map-get? researcher-profiles { researcher: tx-sender })
        )
        { research-proposals-led: (+ (get research-proposals-led 
                                        (default-to { total-reviews-submitted: u0, research-proposals-led: u0, last-academic-activity: u0 }
                                                   (map-get? researcher-profiles { researcher: tx-sender }))) u1),
          last-academic-activity: current-block }
      )
    )
    
    (ok research-id)
  )
)

;; Submit peer review for research proposal
(define-public (submit-peer-review (research-id uint) (approve-funding bool))
  (let 
    (
      (research-proposal (unwrap! (map-get? research-proposals { research-id: research-id }) ERR-RESEARCH-PROPOSAL-MISSING))
      (reviewer-credits (get-researcher-credits tx-sender))
      (academic-influence (determine-academic-influence reviewer-credits))
      (current-block (current-block-height))
    )
    ;; Check if research proposal is under active review
    (asserts! (is-eq (get funding-status research-proposal) REVIEW-ACTIVE) ERR-RESEARCH-INACTIVE)
    
    ;; Check if review period is still open
    (asserts! (<= current-block (get review-end research-proposal)) ERR-REVIEW-DEADLINE-PASSED)
    
    ;; Check if reviewer hasn't already submitted review
    (asserts! (is-none (map-get? peer-reviews { research-id: research-id, reviewer: tx-sender })) ERR-DUPLICATE-REVIEW)
    
    ;; Check if reviewer has academic credits
    (asserts! (> reviewer-credits u0) ERR-INSUFFICIENT-CREDITS)
    
    ;; Record peer review
    (map-set peer-reviews
      { research-id: research-id, reviewer: tx-sender }
      {
        recommendation: approve-funding,
        influence-weight: academic-influence,
        review-timestamp: current-block
      }
    )
    
    ;; Update research proposal vote tallies
    (map-set research-proposals
      { research-id: research-id }
      (merge research-proposal
        (if approve-funding
          { support-votes: (+ (get support-votes research-proposal) academic-influence), opposition-votes: (get opposition-votes research-proposal) }
          { support-votes: (get support-votes research-proposal), opposition-votes: (+ (get opposition-votes research-proposal) academic-influence) }
        )
      )
    )
    
    ;; Update reviewer profile
    (map-set researcher-profiles
      { researcher: tx-sender }
      (merge 
        (default-to 
          { total-reviews-submitted: u0, research-proposals-led: u0, last-academic-activity: u0 }
          (map-get? researcher-profiles { researcher: tx-sender })
        )
        { total-reviews-submitted: (+ (get total-reviews-submitted 
                                         (default-to { total-reviews-submitted: u0, research-proposals-led: u0, last-academic-activity: u0 }
                                                    (map-get? researcher-profiles { researcher: tx-sender }))) u1),
          last-academic-activity: current-block }
      )
    )
    
    (ok academic-influence)
  )
)

;; Conclude review process and determine funding outcome
(define-public (conclude-review-process (research-id uint))
  (let 
    (
      (research-proposal (unwrap! (map-get? research-proposals { research-id: research-id }) ERR-RESEARCH-PROPOSAL-MISSING))
      (current-block (current-block-height))
    )
    ;; Check if review period has concluded
    (asserts! (> current-block (get review-end research-proposal)) ERR-REVIEW-STILL-ONGOING)
    
    ;; Check if proposal is still under active review
    (asserts! (is-eq (get funding-status research-proposal) REVIEW-ACTIVE) ERR-RESEARCH-INACTIVE)
    
    ;; Determine funding decision
    (let ((funding-decision (if (> (get support-votes research-proposal) (get opposition-votes research-proposal))
                              FUNDING-APPROVED
                              FUNDING-REJECTED)))
      (map-set research-proposals
        { research-id: research-id }
        (merge research-proposal { funding-status: funding-decision })
      )
      (ok funding-decision)
    )
  )
)

;; Distribute approved funding
(define-public (distribute-funding (research-id uint))
  (let 
    (
      (research-proposal (unwrap! (map-get? research-proposals { research-id: research-id }) ERR-RESEARCH-PROPOSAL-MISSING))
      (current-block (current-block-height))
    )
    ;; Check if funding was approved
    (asserts! (is-eq (get funding-status research-proposal) FUNDING-APPROVED) ERR-RESEARCH-INACTIVE)
    
    ;; Check if processing time has elapsed
    (asserts! (>= current-block (get distribution-block research-proposal)) ERR-REVIEW-STILL-ONGOING)
    
    ;; Mark funding as distributed
    (map-set research-proposals
      { research-id: research-id }
      (merge research-proposal { funding-status: FUNDS-DISTRIBUTED })
    )
    
    (ok true)
  )
)

;; Read-only functions

;; Get research proposal information
(define-read-only (get-research-proposal (research-id uint))
  (map-get? research-proposals { research-id: research-id })
)

;; Get peer review details
(define-read-only (get-peer-review (research-id uint) (reviewer principal))
  (map-get? peer-reviews { research-id: research-id, reviewer: reviewer })
)

;; Get researcher profile
(define-read-only (get-researcher-profile (researcher principal))
  (map-get? researcher-profiles { researcher: researcher })
)

;; Get academic influence for researcher
(define-read-only (get-academic-influence (researcher principal))
  (let ((credits (get-researcher-credits researcher)))
    (determine-academic-influence credits)
  )
)

;; Get current research proposal counter
(define-read-only (get-research-proposal-counter)
  (var-get research-proposal-id)
)

;; Get academic credit information
(define-read-only (get-academic-credit-info (researcher principal))
  (map-get? academic-credits { researcher: researcher })
)

;; Check eligibility to submit research proposal
(define-read-only (can-submit-research-proposal (researcher principal))
  (>= (get-researcher-credits researcher) MIN-ACADEMIC-CREDITS)
)

;; Get funding status of research proposal
(define-read-only (get-funding-status (research-id uint))
  (match (map-get? research-proposals { research-id: research-id })
    research-proposal (ok (get funding-status research-proposal))
    ERR-RESEARCH-PROPOSAL-MISSING
  )
)

;; Check if research proposal is actively under review
(define-read-only (is-under-active-review (research-id uint))
  (match (map-get? research-proposals { research-id: research-id })
    research-proposal (and 
                       (is-eq (get funding-status research-proposal) REVIEW-ACTIVE)
                       (<= block-height (get review-end research-proposal)))
    false
  )
)