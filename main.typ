#import "format.typ": template
#import "@preview/cetz:0.3.2"

#show: template.with(
  main: "ローカルLLMを用いたOASIS再現実験の報告",
  sub: "Reproduction of OASIS with Local Qwen3-4B-Instruct-2507_q8",
  student: "中村 晴 (Haru Nakamura)", 
  teacher: "村上 力 (Riki Murakami)",    
)

= はじめに

　近年，大規模言語モデル (LLM) を用いたマルチエージェントシミュレーションが注目されている．
社会科学や心理学の分野において，人間の行動や社会現象をシミュレートすることは重要であるが，
人間を対象とした実験はコストや倫理的な制約が大きい．
そこで，LLMを搭載したエージェントに役割を与え，仮想空間で相互作用させる手法が提案されている．

　特に，@yang2024oasis で提案された *OASIS* (Open Agent Social Interaction Simulations) は，
X (旧Twitter) や Reddit などのソーシャルメディアを模倣し，最大100万エージェント規模でのシミュレーションを可能にするフレームワークである．

　しかし，大規模シミュレーションには膨大な計算リソースが必要である．
そこで本稿では，OASISのフレームワークをローカル環境で動作可能な規模に縮小し，
量子化された軽量モデルである *Qwen3-4B-Instruct-2507_q8* @qwen3 を用いて，
エージェント間の対話シミュレーションを行い，その挙動特性について検証を行った結果について報告する．

= OASISの概要

　OASISは，現実のソーシャルメディアプラットフォームを模倣するために設計されたシミュレータであり，
主に以下の5つのコンポーネントで構成されている @yang2024oasis ．

// 図：OASISの構成要素
#figure(
  placement: bottom,
  scope: "parent",
  align(center)[
    #set text(size: 8pt)
    
    #cetz.canvas(length: 0.55cm, {
        import cetz.draw: *
        
        // 1. ノードの配置
        content((0, 7), [
          #block(stroke: black, fill: white, radius: 5pt, inset: 6pt, align(center)[
            #text(weight: "bold")[環境サーバー]\ (DB: ユーザー, 投稿)
          ])
        ], name: "env")

        content((-8.5, 3.5), [
          #block(stroke: black, fill: white, radius: 5pt, inset: 6pt, align(center)[
            #text(weight: "bold")[推薦システム (RecSys)]\ (情報フィルタ)
          ])
        ], name: "recsys")

        content((8.5, 3.5), [
          #block(stroke: black, fill: white, radius: 5pt, inset: 6pt, align(center)[
            #text(weight: "bold")[時間エンジン]\ (行動スケジューラ)
          ])
        ], name: "time")

        content((0, 0), [
          #block(stroke: black, fill: orange.lighten(80%), radius: 5pt, inset: 6pt, align(center)[
            #text(weight: "bold")[エージェント (LLM)]\ (行動 & 記憶)
          ])
        ], name: "agent")

        // 2. 矢印を描画
        line("env.south-west", "recsys.north-east", mark: (end: "stealth"))
        
        line("recsys.south-east", "agent.north-west", mark: (end: "stealth"), name: "filter")
        content((name: "filter", anchor: 0.45), padding: 0.2)[
          #block(fill: white, inset: 2pt, stroke: none)[投稿データ]
        ]
        
        line("time.south-west", "agent.north-east", mark: (end: "stealth"), name: "trigger")
        content((name: "trigger", anchor: 0.45), padding: 0.2)[
          #block(fill: white, inset: 2pt, stroke: none)[実行トリガー]
        ]

        line("agent.north", "env.south", mark: (end: "stealth"), name: "act")
        content("act.mid", anchor: "center")[
          #block(fill: white, inset: 3pt, stroke: none)[行動実行]
        ]
      }
    )
  ],
  caption: "OASISの主要コンポーネント概要",
)

+ *環境サーバー (Environment Server)*: ユーザー情報，投稿，関係性を管理するデータベース．
+ *推薦システム (RecSys)*: エージェントに提示する情報をフィルタリングする．
+ *エージェント (Agent Module)*: LLMを用いてエージェントの行動を決定する．
+ *時間エンジン (Time Engine)*: 行動タイミングを制御する．
+ *推論基盤 (Scalable Inferencer)*: 推論処理基盤．

= 実験計画

== 実験の目的

　本実験の目的は，ローカル環境において *Qwen3-4B-Instruct-2507_q8* @qwen3 を用いたエージェント対話の質的評価を行うことである．
特に，日本語による文脈理解能力と，長期的な議論における一貫性（Coherence）に焦点を当てる．

== 実験環境

- *ハードウェア*: ローカルPC (NVIDIA GeForce RTX 3060, VRAM 6GB)
- *LLMバックエンド*: Ollama (Qwen3-4B-Instruct-2507_q8)
- *エージェント数*: 4体 (User0 ～ User3)
- *対象プラットフォーム*: X (Twitter) ライクな環境

== プロンプトの最適化

　オリジナルのOASISフレームワークでは，エージェントへの入力として長大なコンテキストや
複雑なJSON形式のデータ構造をそのまま与える仕様となっていた．
しかし，本実験で用いる40億パラメータ級の軽量モデルでは，指示の複雑さに追従できず，
出力形式の崩れや文脈の喪失が多発する問題が確認された．

　そこで本実験では，軽量モデルでも安定して動作させるため，入力プロンプトに対して以下の最適化を行った．

- *入力形式の簡略化*: 複雑なJSONオブジェクトをそのまま入力せず，モデルが理解しやすい自然言語やシンプルなリスト形式に変換して提示した．
- *コンテキストの削減*: 議論に直接関係のないメタデータや過剰な過去ログを削除し，入力トークン数を削減することで，モデルの注意（Attention）を重要な情報に向けさせた．

== 実験設定：コールドスタート問題への対処

　マルチエージェント環境において，初期状態から自発的に特定のトピックに関する議論が発生する確率は低い（コールドスタート問題）．
本実験では，特定の社会現象（電子レンジに関する購買議論）を確実に再現するため，
シミュレーション開始直後の 0ターン目において，特定のエージェント（User0）に対し，
「電子レンジを購入しようと思います」という投稿を行う *手動アクション (Manual Action)* を強制的に実行させ，議論の種火（Seed）とした．

== 検証シナリオ：生活相談

　日常的なトピックとして「電子レンジの購入相談」を設定し，以下の役割を与えたエージェント間で自由対話を行わせた．

+ *初期投稿 (User0)*: 「電子レンジを購入しようと思います。おすすめを教えてください」と投稿．
+ *相互作用*: 他のエージェント (User1, User2, User3) がリプライを行い，議論を展開する．
+ *評価*: 会話の自然さ，文脈維持，およびハルシネーションの有無を確認する．

= 実験結果

== 対話ログの分析

　実験の結果，エージェント同士の活発なやり取りが観測された一方で，
軽量モデル特有の課題も浮き彫りとなった．以下に代表的な対話ログを示す．

#figure(
  rect(fill: gray.lighten(95%), stroke: gray, radius: 4pt, inset: 8pt)[
    #set text(size: 9pt)
    *Topic: 電子レンジの購入相談* \
    *User0*: みなさんおはようございます。今日は電子レンジを購入しようと思います。おすすめを教えていただけると幸いです。 \
    
    *User3 (Time 1)*: 電子レンジは本当に便利ですね！私は最近、高効率で調理がしやすいものに変えました。 \
    *User1 (Time 1)*: IH？レンジとは関係ないだろ \
    *User2 (Time 2)*: 1000円以下の電子レンジで調理できるのは、本当に節約にぴったりですね。... \
    *User0 (Time 2)*: ...初心者の方には、操作が簡単で温度や時間を設定できるシンプルなモデルがおすすめです。... \
    ... \
    *User3 (Time 6)*: ...温度や時間を調整できる機能が、調理の質を大きく変えます！ \
    *User0 (Time 7)*: ...温度や時間を調整できる機能が、調理の質を大きく変えます！ \
    *User3 (Time 8)*: ...温度や時間を調整できる機能が、調理の質を高め、日々の生活をよりしやすくしてくれます。 \
    *User0 (Time 9)*: ...温度や時間を調整できる機能が、調理の質を高め、日々の生活をよりしやすくしてくれます。
  ],
  caption: "実験ログ（抜粋）：ループ現象と文脈の混乱",
)

== 観測された事象

=== 1. 反復ループ現象 (Repetition Loop)

　対話が進むにつれ，複数のエージェント（User0とUser3）がほぼ同一のフレーズを繰り返す現象が確認された（Time 6〜9付近）．
「温度や時間を調整できる機能が、調理の質を大きく変えます」といった定型句が相互に伝播し，
会話の多様性が失われる様子が見られた．
これは，自己回帰的な生成において，直前の文脈に含まれる強いトークンに引きずられた結果と考えられる．

=== 2. 文脈の不整合とハルシネーション

　User1は一貫して「IH?レンジとは関係ないだろ」という否定的な発言を繰り返した．
これはペルソナによる役割としては機能しているが，文脈に関わらず定型文を投稿し続ける傾向があった．
また，User2やUser3の発言において「1000円以下の電子レンジ」や「温度設定ができるシンプルなモデル」といった，
現実の商品相場や機能とは乖離した記述（ハルシネーション）が見られた．
特に，IH調理器と電子レンジの機能を混同して議論する場面（Result 2）も確認された．

= 考察

== Qwen3-4Bの特性

　Qwen3-4Bモデル @qwen3 は，日本語の流暢さにおいては高い性能を示したが，
マルチエージェント環境下での長期記憶の保持や，論理的な整合性の維持には課題が残る結果となった．
特に，他者の発言内容に過度に影響され，オウム返しのようなループ状態に陥りやすい点は，
システムプロンプトによる制約（繰り返しペナルティなど）の調整が必要であることを示唆している．

== 今後の展望

　本実験では小規模なモデルでも対話の成立は確認できたが，
より質の高いシミュレーションを行うためには，以下の改善が必要である．

- *反復抑制*: Repetition Penaltyの強化や，過去の自身の発言との類似度チェックの導入．
- *知識の外部化*: RAG (Retrieval-Augmented Generation) を導入し，正確な商品知識（価格帯や機能）を参照させる．
- *性格付けの強化*: 各エージェントのペルソナをより詳細に定義し，画一的な反応を防ぐ．
- *行動選択と発話生成の分離 (Decoupling Action and Content)*
  - *現状の課題*: 行動タイプと発言内容を単一のJSON形式で同時出力させているため，フォーマット制約が言語モデルの表現能力を抑制している．
  - *解決策*: まずツール選択により行動（いいね・投稿など）を決定し，テキスト生成が必要な場合のみ再度文脈を入力して自然言語を生成させる「2段階推論」へ移行する．
  - *期待される効果*: 推論時間は増加するが，発言の自然さと文脈整合性は大幅に向上する．

= 参考文献
#bibliography("refer.bib", title: none)