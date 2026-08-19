"""Builds the four journal essays from one template.

Written as a generator rather than four hand-kept files: the pages share a
head, a header, a footer and a script block, and four copies of that drift
apart the first time one of them is edited. The copy below is the client's,
supplied 19 Aug 2026, transcribed verbatim. Only paragraph breaks and the
pull-quotes are ours; not one word is changed.
"""
import re, io, os, html

V = '?v=1786948800'

ESSAYS = [
 dict(slug='journal-twenty-years', num='01', kick='On the house',
      title='Twenty years, no name on the box',
      img='images/journal/lobby.webp', card='images/journal/lobby.webp',
      alt='An olive shirt, photographed in a lobby',
      desc="Our work carried other people's labels for twenty years. I Am Ratan began when we decided that knowledge deserved a name.",
      lede='There is a particular kind of anonymity that comes from making something very well.',
      pull='A garment is the last five percent of a much longer story.',
      body="""You can spend years learning how a collar should sit. How much ease a shoulder needs. How a particular cloth behaves after washing, pressing, wearing and washing again. You can learn to recognise a good stitch without looking for it. You can know when a shirt is right because the person wearing it stops noticing the shirt altogether.
And still, when the garment leaves the room, your name doesn't leave with it.
For more than twenty years, our work lived like that.
Shirts were made in India, carried elsewhere, and eventually found themselves beneath names that were not ours. The label belonged to someone else. The relationship belonged to someone else. The story belonged to someone else.
The making was ours.
That distinction stayed with us.
Because manufacturing teaches you something that fashion often forgets: a garment is the last five percent of a much longer story.
[PULL]
Before a shirt becomes a shirt, there is cloth to understand. Measurements to interpret. Patterns to correct. Machines to calibrate. Hands to train. Finishing to inspect. And, over time, instincts that cannot quite be written down.
Twenty years of that work creates a kind of knowledge.
Not the knowledge of trends.
The knowledge of what lasts.
[RULE]
I AM RATAN began when we decided that knowledge deserved a name.
Not because we suddenly learnt how to make shirts.
We already knew.
The change was that, for the first time, we wanted to stand behind what we knew.
That is what Reclaim means to us.
Not reclaiming a history that was lost.
Reclaiming authorship of one that was always ours.
The second generation entered the business with a different question. What happens when the people who have spent decades making for brands decide to become the brand?
The answer cannot simply be another label.
It has to be a house.
A house has a point of view. It has standards that don't change because a trend does. It has a memory. It knows what it has made before, and it knows what it refuses to make.
Most importantly, a house knows that its reputation is built slowly.
That is how we intend to build RATAN.
One shirt at a time.
One customer at a time.
One decision at a time.
[RULE]
For twenty years, our hands made the shirt.
Now, for the first time, our name does too."""),

 dict(slug='journal-a-shirt-should-disappear', num='02', kick='On wearing it',
      title='A shirt should disappear',
      img='images/journal/road.webp', card='images/journal/road.webp',
      alt='A stone shirt on the road, sleeves turned back',
      desc='The best shirt in a wardrobe is rarely the one anyone talks about. It is the one reached for without thinking.',
      lede="The best shirt in a man's wardrobe is rarely the one he talks about.",
      pull="A good shirt shouldn't enter the room before you do.",
      body="""It is the one he reaches for without thinking.
The one that works on a Monday morning and still feels right at dinner. The one that survives a long flight, an unexpected meeting, a late evening and the next morning without asking to be treated delicately.
We think this is an underrated quality.
Fashion often asks a garment to be noticed.
We ask a shirt to belong.
That sounds like a small distinction. It isn't.
[RULE]
A shirt has to negotiate with the person wearing it all day.
It sits against the neck. It moves with the shoulder. It gathers at the elbow. It meets the wrist. It spends hours tucked in, then untucked. It has to behave when the wearer is standing, sitting, reaching, driving, travelling.
A photograph cannot tell you any of this.
A hanger certainly cannot.
You learn it by making shirts.
And then making them again.
And then listening to the people who wear them.
This is why we have always believed that fit is more complicated than a number printed on a label.
A 40 is not a man.
Two men can share a chest measurement and have completely different shoulders, posture, proportions and ways of moving.
The difference between a shirt that fits and a shirt that belongs is often invisible.
That is precisely why it matters.
[RULE]
At RATAN, we are interested in that invisible space.
The shoulder that sits without pulling.
The sleeve that arrives at the wrist without needing to be corrected.
The collar that frames the face rather than competing with it.
The amount of room that allows a man to move without making the shirt look oversized.
These details don't announce themselves.
They simply make the wearer feel more like himself.
Perhaps that is our idea of luxury.
Not making the garment louder.
Making the person more comfortable inside it.
[PULL]
It should disappear into the way you carry yourself."""),

 dict(slug='journal-what-a-button-is-for', num='03', kick='On detail',
      title='What a button is for',
      img='images/journal/button.jpg', card='images/journal/button.jpg',
      alt='A button with I AM RATAN engraved around the rim',
      desc='A button has one obvious job. Spend enough time making shirts and you realise nothing on a garment exists entirely by accident.',
      lede='A button has one obvious job. It closes a shirt. That should be enough.',
      pull='Craft is often invisible when it is done well.',
      body="""But spend enough time making shirts and you begin to realise that nothing on a garment exists entirely by accident.
The button has a diameter.
A thickness.
A weight.
A finish.
A position.
A hole count.
A thread.
Even the way it is attached tells you something.
None of these things will appear on a product page as a headline.
Most people will never consciously notice them.
That is precisely the point.
[PULL]
A poorly placed button announces itself immediately. It pulls. It gaps. It sits too high or too low. A loose button begins its own small rebellion after a few wears.
A good one simply does its job.
This is the paradox of detail.
The more attention you give it, the less attention it asks for later.
[RULE]
We have spent more than twenty years learning this language.
Not through theory, but repetition.
Making something thousands of times teaches you to notice the millimetre that someone else might miss.
It teaches you that precision isn't perfectionism.
It is respect for the person who will eventually live in the garment.
That is why we don't think luxury begins with expensive materials.
It begins with attention.
Attention to where a seam ends.
Attention to how a collar rolls.
Attention to whether a cuff sits naturally when a hand moves.
Attention to the button that nobody will ever compliment.
[RULE]
There is a temptation, especially in premium fashion, to make craftsmanship visible.
To expose every detail.
To tell the customer how much work went into something.
We prefer another approach.
Let the craftsmanship do its work quietly.
Let the wearer discover it over time.
Because the finest detail in a shirt is sometimes the one you never have to think about."""),

 dict(slug='journal-the-wardrobe-that-remembers', num='04',
      kick='On the future of menswear',
      title='The wardrobe that remembers',
      img='images/journal/wardrobe.webp', card='images/journal/wardrobe-card.webp',
      alt='Folded shirts in a drawer archive, one colour to a tray',
      desc='Most wardrobes have a memory. The brands do not. What if the relationship did not reset after every purchase?',
      lede='Most wardrobes have a memory. The brands don’t.',
      pull='You don’t need another shirt. You need this one.',
      body="""They remember the shirts that are always worn first.
The colours that disappear from the cupboard faster than the others.
The collar that somehow feels better.
The trousers that never quite work with anything.
The shirt bought for one occasion and worn for five years.
The things a man owns but never reaches for.
The things he wishes he had more of.
The problem is that the wardrobe remembers.
The brands don't.
Every new purchase usually begins from zero.
What size?
Which fit?
Which colour?
Which fabric?
What did you buy last time?
What did you like?
What didn't you like?
For a customer who buys premium clothing, this becomes increasingly strange.
The more a brand knows about him, the better it should be able to serve him.
Yet most fashion remains built around the opposite model:
Come back. Choose again. Explain yourself again.
We wanted to question that.
[RULE]
Wardrobe Management began with a simple idea:
What if the relationship didn't reset after every purchase?
What if we knew how you lived?
What you wore to work.
What you travelled in.
What you reached for on Fridays.
Which colours never left the wardrobe.
Which fabrics you preferred.
Which collars you always returned to.
What was missing.
And what was never needed in the first place.
Then the job changes.
We are no longer asking:
“Which shirt would you like?”
We are asking:
“What does your wardrobe need next?”
That is a different kind of service.
And, we believe, a different kind of luxury.
[RULE]
Our six-month Wardrobe Management programme is built around this idea: a retained relationship in which RATAN studies the individual, researches what he needs and creates shirts around his life rather than asking him to choose from a collection every few months.
It is not about owning more.
It is about owning better.
And eventually, that relationship can move beyond the shirt.
Into trousers.
Into jackets.
Into suits.
Into the wardrobe itself.
This is where we believe menswear is going.
Not towards infinite choice.
Towards less friction and more understanding.
The future of luxury may not be a larger showroom.
It may be a brand that knows you well enough to say:
[PULL]"""),
]

def paras(body, pull):
    out=[]
    for raw in body.split('\n'):
        t=raw.strip()
        if not t: continue
        if t=='[RULE]': out.append('        <hr>'); continue
        if t=='[PULL]':
            out.append('        <blockquote><p>%s</p></blockquote>'%html.escape(pull)); continue
        out.append('        <p>%s</p>'%html.escape(t))
    return '\n'.join(out)

HEAD = open('journal.html',encoding='utf-8').read()
head_top = HEAD[:HEAD.index('<style>')]
footer   = HEAD[HEAD.index('<footer class="foot">'):]

TPL = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title} · I Am Ratan</title>
<link rel="canonical" href="https://www.iamratan.co.in/{slug}.html">
<meta name="description" content="{desc}">
<meta name="theme-color" content="#EDE9E0">
<meta name="twitter:card" content="summary_large_image">
<meta property="og:type" content="article">
<meta property="og:site_name" content="I Am Ratan">
<meta property="og:title" content="{title} · I Am Ratan">
<meta property="og:description" content="{desc}">
<meta property="og:image" content="https://www.iamratan.co.in/images/og-card.jpg">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:image" content="https://www.iamratan.co.in/images/og-card.jpg">
<link rel="icon" href="assets/favicon-32.png" sizes="32x32">
<link rel="icon" href="assets/favicon-16.png" sizes="16x16">
<link rel="apple-touch-icon" href="assets/apple-touch-icon.png">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Anek+Latin:wght@100..800&family=IBM+Plex+Mono:wght@300;400;500&display=swap" rel="stylesheet">
<link rel="stylesheet" href="assets/iar-house.css{v}">
</head>
<body data-no-grounds>
<a class="skip" href="#main">Skip to content</a>

<header class="top label">
  <a class="markwrap" href="index.html" aria-label="I Am Ratan, home"><span class="mk" aria-hidden="true"><span class="mk-letters"></span><span class="mk-badger"><i class="mk-body"></i><i class="mk-head"></i></span></span></a>
  <nav class="nav">
    <a href="index.html">Home</a>
    <a href="shop.html">Shop</a>
    <a href="bespoke.html">Bespoke</a>
    <a href="house.html">About us</a>
  </nav>
  <span class="muted">Hyderabad</span>
</header>

<main id="main">
  <article>
    <figure class="essay-hero" style="margin-top:var(--clear)">
      <img src="{img}" alt="{alt}" fetchpriority="high" decoding="async">
    </figure>

    <div class="wrap">
      <header class="essay-head">
        <p class="label muted essay-kick"><span class="fig">{num}</span> &nbsp;·&nbsp; {kick}</p>
        <h1 class="essay-name">{title}</h1>
        <p class="essay-lede">{lede}</p>
      </header>

      <div class="essay-body">
{body}
      </div>
    </div>

    <nav class="essay-next" aria-label="More from the journal">
      <div class="wrap">
{next}
      </div>
    </nav>
  </article>
</main>

{footer}"""

def card(e):
    return ('        <a class="enx" href="%s.html">\n'
            '          <span class="enx-shot"><img src="%s" alt="" loading="lazy" decoding="async"></span>\n'
            '          <p class="label muted">%s</p>\n'
            '          <p class="enx-name">%s</p>\n'
            '        </a>')%(e['slug'],e['card'],e['kick'],html.escape(e['title']))

for i,e in enumerate(ESSAYS):
    nxt=[ESSAYS[(i+1)%len(ESSAYS)], ESSAYS[(i+2)%len(ESSAYS)]]
    out=TPL.format(v=V, body=paras(e['body'],e['pull']),
                   next='\n'.join(card(n) for n in nxt),
                   footer=footer, **{k:e[k] for k in
                     ('slug','num','kick','title','img','alt','desc','lede')})
    open(e['slug']+'.html','w',encoding='utf-8').write(out)
    print('  wrote %-38s %5.1f KB'%(e['slug']+'.html',len(out)/1024))
