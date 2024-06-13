(deffacts starting-pile
    (piles
        (pile
            (assert (card (color green) (number 0)))
            (assert (card (color white) (number 0)))
            (assert (card (color blue) (number 0)))
            (assert (card (color yellow) (number 0)))
            (assert (card (color red) (number 0)))
            )
        )
    )

(deffacts starting-discard
    (discard (cards))
    )

(deffacts lives-remaining
    (lives-remaining 3)
    )

(deffacts hints-remaining
    (hints-remaining 8)
    )
