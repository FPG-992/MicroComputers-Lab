#import "@local/template:0.1.0": template
#show: template.with(
    title: (
        [Εργαστήριο Μικροϋπολογιστών],
        [3η Εργαστηριακή Άσκηση]
    ),
    authors: (
        "Χριστόφορος Χαραλάμπους 03121614",
        "Φίλιππος Γιαννακόπουλος 03121629",
    ),
)

= Ζήτημα 3.1
Το Ζήτημα 3.1 βρίσκεται στο αρχείο `erg3.1.asm`.

#let one = read("erg3.1.X/erg3.1.asm")
#raw(one, lang: "asm")

#pagebreak()

= Ζήτημα 3.2
Το Ζήτημα 3.2 βρίσκεται στο αρχείο `erg3.2.c`.

#let two = read("erg3.2.X/erg3.2.c")
#raw(two, lang: "C")

#pagebreak()

= Ζήτημα 3.3
Το Ζήτημα 3.3 βρίσκεται στο αρχείο `erg3.3.c`.

#let three = read("erg3.3.X/erg3.3.c")
#raw(three, lang: "C")
