(defmodule CORE (import MAIN ?ALL) (export ?ALL))

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
    (declare (salience -10000))
    ?c <- (command (player-name ?pn) (action $?ac))
    (not (available-action (player-name ?pn) (action $?ac)))
    =>
    (retract ?c)
    (println "Bad command.")
    )

(defrule process-command
    (command (player-name ?pn) (action $?ac))
    (exists (available-action (player-name ?pn) (action $?ac)))
    =>
    (do-for-all-facts ((?action available-action)) TRUE
        (retract ?action)
        )
    (focus GAME CORE)
    )

(defrule available-action-give-hint
    (current-turn ?pn)
    (player (name ?on&:(neq ?on ?pn)) (hand $?other-player-hand))
    (hints-remaining ?hrem&:(> ?hrem 0))
    (not (command (action $?)))
    =>
    ; Asserting the same fact multiple times doesn't matter, so we just go through all cards in the other player's hand.
    (foreach ?card ?other-player-hand
        (assert (available-action (player-name ?pn) (action give-hint ?on color (fact-slot-value ?card color))))
        (assert (available-action (player-name ?pn) (action give-hint ?on number (fact-slot-value ?card number))))
        )
    )

(defrule available-action-give-play-or-discard
    (current-turn ?pn)
    (player (name ?pn) (hand $?player-hand))
    (not (command (action $?)))
    =>
    (loop-for-count (?card-index 1 (length$ ?player-hand))
        (assert
            (available-action (player-name ?pn) (action play ?card-index))
            (available-action (player-name ?pn) (action discard ?card-index))
            )
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
    ?p <- (player (hand))
    ?d <- (deck (cards $?deck))
    =>
    (bind ?new-hand (subseq$ ?deck 1 ?*cards-per-player*))
    (modify ?p (hand ?new-hand))
    (modify ?d (cards (delete$ ?deck 1 ?*cards-per-player*)))
    )
