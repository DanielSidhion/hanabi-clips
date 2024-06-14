(defmodule CORE (import MAIN ?ALL) (export ?ALL))

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
    (println "GAME WON")
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
    (println "GAME OVER")
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
    (assert (available-command (player-name ?pn) (action give-hint ?on color (fact-slot-value ?card color))))
    (assert (available-command (player-name ?pn) (action give-hint ?on number (fact-slot-value ?card number))))
    )

(defrule available-command-give-play-or-discard
    (current-turn ?pn)
    (hand-card (player-name ?pn) (index ?card-index))
    (not (command (action $?)))
    =>
    (assert
        (available-command (player-name ?pn) (action play ?card-index))
        (available-command (player-name ?pn) (action discard ?card-index))
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
        (assert (hand-card (player-name ?pn) (index ?card-index) (card ?curr-card)))
        (assert (card-hints (player-name ?pn) (index ?card-index)))
        )
    (modify ?d (cards (delete$ ?deck 1 ?*cards-per-player*)))
    )
