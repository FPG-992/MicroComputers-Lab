#import "@local/template:0.1.0": template
#show: template.with(
    title: (
        [Εργαστήριο Μικροϋπολογιστών],
        [4η Εργαστηριακή Άσκηση]
    ),
    authors: (
        "Χριστόφορος Χαραλάμπους 03121614",
        "Φίλιππος Γιαννακόπουλος 03121629",
    ),
)

= Ζήτημα 4.1
Το Ζήτημα 4.1 βρίσκεται στο αρχείο `erg4.1.asm`.

#let one = read("erg4.1.X/erg4.1.asm")
#raw(one, lang: "asm")

#pagebreak()

= Ζήτημα 4.2
Το Ζήτημα 4.2 βρίσκεται στο αρχείο `erg4.2.c`.

#let two = read("erg4.2.X/erg4.2.c")
#raw(two, lang: "C")

#pagebreak()

= Ζήτημα 4.4
Το Ζήτημα 4.4 βρίσκεται στο αρχείο `erg4.3.c`.

#let three = read("erg4.3.X/erg4.3.c")
#raw(three, lang: "C")
