(defmodule MAIN (export ?ALL))

(defglobal
    ?*num-players* = 0
    ?*cards-per-player* = 0
    )

(deftemplate player
    (slot name)
    )

(deftemplate hand-card
    (slot player-name)
    (slot index)
    (slot card)
    )

(deftemplate card-hints
    (slot player-name)
    (slot index)
    (multislot color)
    (multislot number)
    )

(deftemplate command
    (slot player-name)
    (multislot action)
    )

(deftemplate available-command
    (slot player-name)
    (multislot action)
    )

(deftemplate card
    (slot color (allowed-values green white blue yellow red))
    (slot number (allowed-values 0 1 2 3 4 5))
    )

(deftemplate piles
    (multislot pile)
    )

(deftemplate discard
    (multislot cards)
    )

(deftemplate deck
    (multislot cards)
    )

(deftemplate internal-action
    (multislot action)
    )

(defrule start
    =>
    (focus INITIAL CORE COMMAND)
    )
