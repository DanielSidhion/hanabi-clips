(deftemplate player
    (slot name)
    (multislot hand))

(deftemplate command
    (slot player_name)
    (multislot action))

(defrule bad_command
    (declare (salience -10000))
    ?c <- (command)
    =>
    (println "Bad command.")
    (retract ?c))
