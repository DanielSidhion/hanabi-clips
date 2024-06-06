(deftemplate card
    (slot color (allowed-values green white blue yellow red))
    (slot number (allowed-values 0 1 2 3 4 5)))

(deftemplate piles
    (multislot pile))

(deffacts player_ds
    (player
        (name ds)
        (hand
            (assert (card (color green) (number 1)))
            (assert (card (color green) (number 2))))))

(deffacts starting_pile
    (piles
        (pile
            (assert (card (color green) (number 0)))
            (assert (card (color white) (number 0)))
            (assert (card (color blue) (number 0)))
            (assert (card (color yellow) (number 0)))
            (assert (card (color red) (number 0))))))

(defrule card-matches-pile
    ?cmd <- (command (player_name ?p) (action play ?color ?number&:(> ?number 0)))
    ?card <- (card (color ?color) (number ?number))
    ?pl <- (player (name ?p) (hand $?hand-before ?card $?hand-after))
    ?prev_card <- (card (color ?color) (number =(- ?number 1)))
    ?pile <- (piles (pile $?pile-before ?prev_card $?pile-after))
    =>
    (retract ?cmd)
    (bind ?new-hand (create$ ?hand-before ?hand-after (assert (card (color white) (number 1)))))
    (modify ?pl (hand ?new-hand))
    (modify ?pile (pile (create$ ?pile-before ?card ?pile-after)))
    )

(defrule player-has-green-1
    ?c <- (card (color green) (number 1))
    (player (hand $? ?c $?))
    =>
    (println "Player has a green 1!"))
