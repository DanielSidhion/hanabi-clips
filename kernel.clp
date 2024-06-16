(defmodule CORE (import MAIN ?ALL) (export ?ALL))

(defrule coalesce-identical-effects
    ; This must run before the rule that sends ordered effects.
    (declare (salience -9999))
    (game-effect (sequence ?seq1) (players $?players) (type ?type) (data $?data))
    ?subsequent-effect <- (game-effect (sequence ?seq2) (players $?players) (type ?type) (data $?data))
    (test
        (or
            (and
                ; ?seq1 is smaller than ?seq2.
                (= (str-compare ?seq1 ?seq2) -1)
                (= (str-length ?seq1) (str-length ?seq2))
                )
            ; ?seq1 is smaller than ?seq2.
            (< (str-length ?seq1) (str-length ?seq2))
            )
        )
    =>
    ; Since ?seq1 is smaller, we'll keep it and retract the effect with higher sequence.
    (retract ?subsequent-effect)
    )

(defrule send-effect-ordered
    (declare (salience -10000))
    ?effect <- (game-effect (sequence ?seq))
    (not
        (and
            (game-effect (sequence ?other-seq))
            (or
                (and
                    ; ?other-seq is smaller than ?seq. This would invalidate the ordering.
                    (test (= (str-compare ?seq ?other-seq) 1))
                    ; Necessary for the str-compare to hold.
                    (test (= (str-length ?seq) (str-length ?other-seq)))
                    )
                ; ?other-seq is smaller than ?seq. This would invalidate the ordering.
                (test (> (str-length ?seq) (str-length ?other-seq)))
                )
            )
        )
    =>
    (ppfact ?effect ?*game-effects-router*)
    (retract ?effect)
    )

(defrule effect-when-deck-size-changes
    (deck (cards $?cards))
    =>
    (assert (game-effect (players ALL) (type DECK-SIZE) (data (length$ ?cards))))
    )

(defrule effect-when-lives-changes
    (lives-remaining ?lives)
    =>
    (assert (game-effect (players ALL) (type UPDATE-LIVES) (data ?lives)))
    )

(defrule effect-when-hints-changes
    (hints-remaining ?hints)
    =>
    (assert (game-effect (players ALL) (type UPDATE-HINTS) (data ?hints)))
    )

(defrule effect-when-card-color-hint-changes
    (card-hints (player-name ?pn) (index ?index) (color $?color-hints&:(> (length$ $?color-hints) 0)))
    =>
    (assert (game-effect (players ALL) (type UPDATE-CARD-HINTS) (data ?pn ?index color ?color-hints)))
    )

(defrule effect-when-card-number-hint-changes
    (card-hints (player-name ?pn) (index ?index) (number $?number-hints&:(> (length$ $?number-hints) 0)))
    =>
    (assert (game-effect (players ALL) (type UPDATE-CARD-HINTS) (data ?pn ?index number ?number-hints)))
    )

(defrule effect-when-turn-changes
    ; Assumption is that all other effects should be generated first, because they're consequence of the action of the player who just had their turn. We only show the next turn's player after those effects are done.
    (declare (salience -1))
    (current-turn ?pn)
    =>
    (assert (game-effect (players ALL) (type SET-TURN) (data ?pn)))
    )

(defrule game-score
    ; Just so the score updates before game is declared won or over.
    (declare (salience 1))
    (piles (pile $?pile-cards))
    =>
    (do-for-fact ((?s game-score))
        (retract ?s)
        )
    (bind ?curr-score 0)
    (foreach ?card ?pile-cards
        (bind ?curr-score (+ ?curr-score (fact-slot-value ?card number)))
        )
    (assert (game-score ?curr-score))
    (assert (game-effect (players ALL) (type UPDATE-SCORE) (data ?curr-score)))
    )

(defrule game-won
    (piles (pile $?pile-cards))
    ?green <- (card (color green) (number 5))
    ?white <- (card (color white) (number 5))
    ?blue <- (card (color blue) (number 5))
    ?yellow <- (card (color yellow) (number 5))
    ?red <- (card (color red) (number 5))
    (test (member$ ?green $?pile-cards))
    (test (member$ ?white $?pile-cards))
    (test (member$ ?blue $?pile-cards))
    (test (member$ ?yellow $?pile-cards))
    (test (member$ ?red $?pile-cards))
    =>
    (assert (game-effect (players ALL) (type GAME-RESULT) (data WIN)))
    )

(defrule game-over
    (declare (salience -1))
    (or
        (lives-remaining 0)
        (forall (player (name ?pn))
            (hand-card (player-name ?pn) (index ?index&:(= ?index ?*cards-per-player*)) (card nil))
            )
        )
    =>
    (assert (game-effect (players ALL) (type GAME-RESULT) (data LOSS)))
    )

(deffunction go-to-next-player ()
    (assert (internal-action (action progress-turn)))
    )

(defrule progress-turn
    ?cmd <- (internal-action (action progress-turn))
    (turn-order $?order)
    ?ct <- (current-turn ?pn)
    =>
    (retract ?cmd)
    (bind ?current-player-index (member$ ?pn ?order))
    (bind ?next-player-index (+ ?current-player-index 1))
    (bind ?next-player-index (if (> ?next-player-index ?*num-players*) then 1 else ?next-player-index))
    (retract ?ct)
    (assert (current-turn (nth$ ?next-player-index ?order)))
    )

(defmodule COMMAND (import MAIN ?ALL))

(defrule bad-command
    ?c <- (command (player-name ?pn) (action $?ac))
    (not (available-command (player-name ?pn) (action $?ac)))
    =>
    (retract ?c)
    (println "Bad command.")
    )

(defrule process-command
    (command (player-name ?pn) (action $?ac))
    (exists (available-command (player-name ?pn) (action $?ac)))
    =>
    (do-for-all-facts ((?action available-command)) TRUE
        (retract ?action)
        )
    (focus GAME CORE)
    )

(defrule available-command-give-hint
    (current-turn ?pn)
    (hand-card (player-name ?on&:(neq ?on ?pn)) (card ?card))
    (hints-remaining ?hrem&:(> ?hrem 0))
    (not (command (action $?)))
    =>
    ; Asserting the same fact multiple times doesn't matter, so we'll do this for all cards in other players' hands.
    (bind ?give-hint-color-data (create$ give-hint ?on color (fact-slot-value ?card color)))
    (assert (available-command (player-name ?pn) (action ?give-hint-color-data)))
    (assert (game-effect (players ?pn) (type AVAILABLE-ACTION) (data ?give-hint-color-data)))
    (bind ?give-hint-number-data (create$ give-hint ?on number (fact-slot-value ?card number)))
    (assert (available-command (player-name ?pn) (action ?give-hint-number-data)))
    (assert (game-effect (players ?pn) (type AVAILABLE-ACTION) (data ?give-hint-number-data)))
    )

(defrule available-command-give-play-or-discard
    (current-turn ?pn)
    (hand-card (player-name ?pn) (index ?card-index))
    (not (command (action $?)))
    =>
    (assert
        (available-command (player-name ?pn) (action play ?card-index))
        (game-effect (players ?pn) (type AVAILABLE-ACTION) (data play ?card-index))
        (available-command (player-name ?pn) (action discard ?card-index))
        (game-effect (players ?pn) (type AVAILABLE-ACTION) (data discard ?card-index))
        )
    )

(defmodule INITIAL (import MAIN ?ALL))

(defrule start-player-count
    =>
    (assert (players))
    )

(defrule count-players
    (player (name ?n))
    ?pl <- (players $?plist)
    (test (not (member$ ?n $?plist)))
    =>
    (retract ?pl)
    (assert (players (create$ ?plist ?n)))
    )

(defrule player-count-finished
    (players $?plist)
    (forall
        (player (name ?n))
        (test (member$ ?n ?plist))
        )
    =>
    (bind ?*num-players* (length$ ?plist))
    (assert (player-count-done))
    )

(defrule determine-cards-per-player
    (declare (salience 10000))
    (player-count-done)
    =>
    (bind ?*cards-per-player* (if (> ?*num-players* 3) then 4 else 5))
    )

(defrule deal-cards
    (player-count-done)
    (player (name ?pn))
    (not (hand-card (player-name ?pn)))
    ?d <- (deck (cards $?deck))
    =>
    (loop-for-count (?card-index ?*cards-per-player*)
        (bind ?curr-card (nth$ ?card-index ?deck))
        (deal-card ?pn ?card-index ?curr-card)
        ; (assert (hand-card (player-name ?pn) (index ?card-index) (card ?curr-card)))
        (assert (card-hints (player-name ?pn) (index ?card-index)))
        )
    (modify ?d (cards (delete$ ?deck 1 ?*cards-per-player*)))
    )
