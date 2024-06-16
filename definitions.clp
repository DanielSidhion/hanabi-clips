(defmodule MAIN (export ?ALL))

(defglobal
    ?*num-players* = 0
    ?*cards-per-player* = 0
    ; This should be set by the wrapper software to a different value before running, so it can properly observe the effects without any other output messing with it.
    ?*game-effects-router* = stdout
    )

(deftemplate player
    (slot name (type STRING))
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

(deftemplate game-effect
    ; Which player(s) to route this effect to.
    (multislot players (type LEXEME) (allowed-symbols ALL) (default ALL))
    (slot type (type SYMBOL) (allowed-values UPDATE-SCORE DEAL-CARD PLAY-CARD DISCARD-CARD HINT UPDATE-CARD-HINTS GAME-RESULT SET-TURN AVAILABLE-ACTION DECK-SIZE UPDATE-PILE UPDATE-DISCARD UPDATE-LIVES UPDATE-HINTS) (default ?NONE))
    (slot sequence (type SYMBOL) (default-dynamic (gensym*)))
    (multislot data)
    )

(deffunction deal-card (?player-name ?card-index ?card-fact)
    (assert (hand-card (player-name ?player-name) (index ?card-index) (card ?card-fact)))
    (assert (game-effect (players ?player-name) (type DEAL-CARD) (data ?player-name ?card-index nil)))
    (do-for-all-facts ((?player player))
        (neq ?player:name ?player-name)
        ; Only other players can see the card a player was given.
        (assert (game-effect (players ?player:name) (type DEAL-CARD) (data ?player-name ?card-index ?card-fact)))
        )
    )

(defrule start
    =>
    (focus INITIAL CORE COMMAND)
    )

(defrule effects-are-available
    (game-effect)
    =>
    (focus CORE)
    )

(defrule new-command-available
    (command)
    =>
    (focus COMMAND)
    )
