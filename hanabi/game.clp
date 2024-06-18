(defmodule GAME (import MAIN ?ALL) (import CORE ?ALL))

(defrule played-card-matches-pile
    ?cmd <- (command (player-name ?pn) (action play ?card-index))
    ?card <- (card (color ?color) (number ?number))
    ?hc <- (hand-card (player-name ?pn) (index ?card-index) (card ?card))
    ?hint <- (card-hints (player-name ?pn) (index ?card-index))
    ?prev-card <- (card (color ?color) (number =(- ?number 1)))
    ?pile <- (piles (pile $?pile-before ?prev-card $?pile-after))
    =>
    (retract ?cmd ?hc ?hint)
    (modify ?pile (pile (create$ ?pile-before ?card ?pile-after)))
    (assert (game-effect (players ALL) (type PLAY-CARD) (data ?pn ?card-index SUCCESS)))
    (assert (game-effect (players ALL) (type UPDATE-PILE) (data ?color ?number)))

    (assert (internal-action (action shift-cards-and-deal ?pn ?card-index)))
    (go-to-next-player)
    )

(defrule played-card-goes-to-discard
    ?cmd <- (command (player-name ?pn) (action play ?card-index))
    ?card <- (card (color ?color) (number ?number))
    ?hc <- (hand-card (player-name ?pn) (index ?card-index) (card ?card))
    ?hint <- (card-hints (player-name ?pn) (index ?card-index))
    ?prev-card <- (card (color ?color) (number =(- ?number 1)))
    (not (piles (pile $? ?prev-card $?)))
    ?discard <- (discard (cards $?discard-cards))
    ?lr <- (lives-remaining ?num-lives)
    =>
    (retract ?cmd ?hc ?lr)
    (assert (lives-remaining (- ?num-lives 1)))

    (assert (game-effect (players ALL) (type PLAY-CARD) (data ?pn ?card-index FAIL)))
    (assert (game-effect (players ALL) (type UPDATE-DISCARD) (data ?color ?number)))

    (assert (internal-action (action shift-cards-and-deal ?pn ?card-index)))
    (modify ?discard (cards (create$ ?discard-cards ?card)))
    (go-to-next-player)
    )

(defrule card-discarded
    ?cmd <- (command (player-name ?pn) (action discard ?card-index))
    ?card <- (card (color ?color) (number ?number))
    ?hc <- (hand-card (player-name ?pn) (index ?card-index) (card ?card))
    ?hint <- (card-hints (player-name ?pn) (index ?card-index))
    ?discard <- (discard (cards $?discard-cards))
    ?hr <- (hints-remaining ?num-hints)
    =>
    (retract ?cmd ?hc ?hint ?hr)

    (assert (game-effect (players ALL) (type DISCARD-CARD) (data ?pn ?card-index)))
    (assert (game-effect (players ALL) (type UPDATE-DISCARD) (data ?color ?number)))

    (modify ?discard (cards (create$ ?discard-cards ?card)))
    (assert
        (internal-action (action shift-cards-and-deal ?pn ?card-index))
        (hints-remaining (max 8 (+ ?num-hints 1)))
        )
    (go-to-next-player)
    )

(defrule shift-cards-and-deal-new-one
    ?cmd <- (internal-action (action shift-cards-and-deal ?pn ?card-index))
    ?deck <- (deck (cards $?cards))
    =>
    (retract ?cmd)
    (bind ?next-card (nth$ 1 ?cards))
    (modify ?deck (cards (rest$ ?cards)))

    ; Make all other cards/hints above the card that was played shift to the left so the newest card comes as the last card in hand.
    (do-for-all-facts ((?curr-card-or-hint hand-card card-hints))
        (and
            (eq ?curr-card-or-hint:player-name ?pn)
            (> ?curr-card-or-hint:index ?card-index)
            )
        (modify ?curr-card-or-hint (index (- ?curr-card-or-hint:index 1)))
        )
    
    (assert
        (deal-card ?pn ?*cards-per-player* ?next-card)
        ; (hand-card (player-name ?pn) (index ?*cards-per-player*) (card ?next-card))
        (card-hints (player-name ?pn) (index ?*cards-per-player*))
        )
    )

(defrule hint-given
    ?cmd <- (command (player-name ?issuing-pn) (action give-hint ?pn ?hint-type ?hint-value))
    ?hr <- (hints-remaining ?num-hints&:(> ?num-hints 0))
    =>
    (retract ?cmd ?hr)

    (assert (game-effect (players ALL) (type HINT) (data ?issuing-pn ?pn ?hint-type ?hint-value)))

    (assert (hints-remaining (- ?num-hints 1)))
    (assert (internal-action (action add-hint ?pn ?hint-type ?hint-value)))
    (go-to-next-player)
    )

(defrule apply-color-hint
    (internal-action (action add-hint ?pn color ?color))
    ?c <- (card (color ?color))
    ?hc <- (hand-card (player-name ?pn) (index ?index) (card ?c))
    ?hint <- (card-hints (player-name ?pn) (index ?index) (color $?color-hints))
    (test (not (member$ ?color $?color-hints)))
    =>
    (modify ?hint (color (create$ ?color-hints ?color)))
    )

(defrule apply-negative-color-hint
    (internal-action (action add-hint ?pn color ?color))
    ?c <- (card (color ?other-color&:(neq ?other-color ?color)))
    ?hc <- (hand-card (player-name ?pn) (index ?index) (card ?c))
    ?hint <- (card-hints (player-name ?pn) (index ?index) (color $?color-hints))
    (test (not (member$ (sym-cat not- ?color) $?color-hints)))
    =>
    (bind ?negative-hint (sym-cat not- ?color))
    (modify ?hint (color (create$ ?color-hints ?negative-hint)))
    )

(defrule apply-number-hint
    (internal-action (action add-hint ?pn number ?number))
    ?c <- (card (number ?number))
    ?hc <- (hand-card (player-name ?pn) (index ?index) (card ?c))
    ?hint <- (card-hints (player-name ?pn) (index ?index) (number $?number-hints))
    (test (not (member$ ?number $?number-hints)))
    =>
    (modify ?hint (number (create$ ?number-hints ?number)))
    )

(defrule apply-negative-number-hint
    (internal-action (action add-hint ?pn number ?number))
    ?c <- (card (number ?other-number&:(<> ?other-number ?number)))
    ?hc <- (hand-card (player-name ?pn) (index ?index) (card ?c))
    ?hint <- (card-hints (player-name ?pn) (index ?index) (number $?number-hints))
    (test (not (member$ (sym-cat not- ?number) $?number-hints)))
    =>
    (bind ?negative-hint (sym-cat not- ?number))
    (modify ?hint (number (create$ ?number-hints ?negative-hint)))
    )

; The lower salience means this will only run after all triggers of the rule that applies the hint are done.
(defrule finish-applying-hint
    (declare (salience -1))
    ?cmd <- (internal-action (action add-hint $?))
    =>
    (retract ?cmd)
    )
