#!/usr/bin/awk -f

BEGIN {
    in_example = 0
	create_image_tag = 0
	capturing = 0
}

/!\[.*\]\(.*\)/ {
	create_image_tag = 0
}

{
	if (create_image_tag) {
		print "![" name "](https://raw.githubusercontent.com/Robotechnic/alchemist/master/images/" name "1.png)"
		create_image_tag = 0
	}
	print
}

match($0,/^<!--EXAMPLE\((.*)\)-->$/,group) {
    in_example = 1
	name = group[1]
    next
}

/^````typ$/ {
    if (in_example) {
        capturing = 1
		print "#import \"@preview/alchemist:0.1.1\":*" > "images/" name ".typ"
		print "#set page(width: auto, height: auto, margin: .1cm, fill: white)" >> "images/" name ".typ"
        next
    }
}

/^````$/ {
    if (capturing) {
        capturing = 0
        in_example = 0
		system("typst compile -f png \"images/" name ".typ\" \"images/" name "{n}.png\"")
		create_image_tag = 1
        next
    }
}

capturing {
    print >> "images/" name ".typ"
}
