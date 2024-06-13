(defmodule GAME (import MAIN ?ALL) (import CORE ?ALL))

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
        (forall (player (hand $?player-hand))
            (test (= (length$ $?player-hand) (- ?*cards-per-player* 1)))
            )
        )
    =>
    (println "GAME OVER")
    )

(defrule card-matches-pile
    (declare (salience 1))
    ?cmd <- (command (player-name ?p) (action play ?card-index))
    ?card <- (card (color ?color) (number ?number))
    ?pl <- (player (name ?p) (hand $?player-hand))
    (test (eq (nth$ ?card-index $?player-hand) ?card))
    ?deck <- (deck (cards $?cards))
    ?prev-card <- (card (color ?color) (number =(- ?number 1)))
    ?pile <- (piles (pile $?pile-before ?prev-card $?pile-after))
    =>
    (retract ?cmd)
    (bind ?next-card (first$ ?cards))
    (modify ?deck (cards (rest$ ?cards)))
    (bind ?hand-without-card (delete$ ?player-hand ?card-index ?card-index))
    (modify ?pl (hand (create$ ?hand-without-card ?next-card)))
    (modify ?pile (pile (create$ ?pile-before ?card ?pile-after)))
    (go-to-next-player)
    )

(defrule card-goes-to-discard
    ?cmd <- (command (player-name ?p) (action play ?card-index))
    ?card <- (card (color ?color) (number ?number))
    ?pl <- (player (name ?p) (hand $?player-hand))
    (test (eq (nth$ ?card-index $?player-hand) ?card))
    ?deck <- (deck (cards $?cards))
    ?discard <- (discard (cards $?discard-cards))
    ?lr <- (lives-remaining ?num-lives)
    =>
    (retract ?cmd)
    (bind ?next-card (first$ ?cards))
    (modify ?deck (cards (rest$ ?cards)))
    (bind ?hand-without-card (delete$ ?player-hand ?card-index ?card-index))
    (modify ?pl (hand (create$ ?hand-without-card ?next-card)))
    (modify ?discard (cards (create$ ?discard-cards ?card)))
    (retract ?lr)
    (assert (lives-remaining (- ?num-lives 1)))
    (go-to-next-player)
    )

(defrule card-discarded
    ?cmd <- (command (player-name ?p) (action discard ?card-index))
    ?card <- (card (color ?color) (number ?number))
    ?pl <- (player (name ?p) (hand $?player-hand))
    (test (eq (nth$ ?card-index $?player-hand) ?card))
    ?deck <- (deck (cards $?cards))
    ?discard <- (discard (cards $?discard-cards))
    ?hr <- (hints-remaining ?num-hints)
    =>
    (retract ?cmd)
    (bind ?next-card (first$ ?cards))
    (modify ?deck (cards (rest$ ?cards)))
    (bind ?hand-without-card (delete$ ?player-hand ?card-index ?card-index))
    (modify ?pl (hand (create$ ?hand-without-card ?next-card)))
    (modify ?discard (cards (create$ ?discard-cards ?card)))
    (retract ?hr)
    (assert (hints-remaining (max 8 (+ ?num-hints 1))))
    (go-to-next-player)
    )

(defrule hint-given
    ?cmd <- (command (player-name ?p) (action give-hint ?ph ?hint-type ?hint-value))
    (player (name ?ph))
    ?hr <- (hints-remaining ?num-hints&:(> ?num-hints 0))
    =>
    (retract ?cmd ?hr)
    (assert (hints-remaining (- ?num-hints 1)))
    (go-to-next-player)
    )

; TODO: track hints that were given for each card in player's hand.
