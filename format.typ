
#let template(
  main: [],
  sub: [],
  student: [],
  teacher: [],
  body
) = {
  let header(content: []) = {
    set align(center)
    text(
      size: 10pt,
      font: "IPAGothic",
    )[#content]
  }

  let title(main: [], sub: []) = {
    v(1cm)
    text(
      size: 20pt,
      font: "IPAGothic",
      weight: "medium",
    )[#main]
    v(0cm)
    text(
      size: 11pt,
      font: "IPAGothic",
      weight: "medium",
    )[#sub]
  }

  let author(stduent: [], teacher: []) = {
    v(0.5cm)
    set align(center)
    text(
      size: 12pt,
      font: "IPAGothic",
    )[#stduent]
    h(1cm)
    text(
      size: 12pt,
      font: "IPAGothic",
    )[指導教員 #h(0.5cm) #teacher]
    v(1cm)
  }

  set page(
    paper: "a4",
    numbering: "1",
    number-align: center,
    margin: (
      top: 2cm,
      bottom: 1cm,
      left: 2cm,
      right: 2cm,
    ),
    columns: 2,
    header: header(content: "情報・ソフトウェア系 分野専門セミナー 報告書"),
  )

  set columns(
    gutter: 8mm,
  )

  set heading(numbering: "1.1", )
  show heading: it => [
    #set text(size: 12pt, weight: "medium", font: "IPAGothic")
    #it
    #v(0.2cm)
  ]

  set par(justify: true, leading: 1em)
  set text(size: 10pt, font: "IPAMincho")

  set math.equation(numbering: "(1)")

  show figure.where(
    kind: table
  ): set figure.caption(position: top)


  set cite(
    form: "normal",
  )

  place(
    top + center,
    scope: "parent",
    float: true,
    {
      title(
        main: main,
        sub: sub,
      )
      author(
        stduent: student,
        teacher: teacher,
      )
    }
  )

  body
}
