"""
보스/영웅/호위 대사 번역 JSON 생성 스크립트
- boss_dialogues.py의 BOSS_DIALOGUES, BOSS_VARIANT_DIALOGUES
- hero_dialogues.py의 HERO_DIALOGUES
- bodyguard_follower.py의 HERO_IDLE_DIALOGUES, DEFAULT_DIALOGUES
"""
import json
import os

# ── 보스 대사 영문 번역 ──
BOSS_EN = {
    1: {
        "battle_start": [
            "Let's have an exciting match!",
            "Try to keep up with this rhythm!",
            "Let the music play~!",
        ],
        "scored": [
            "Can you follow this rhythm?",
            "Ding dong~ One point!",
            "Dancing to my beat!",
        ],
        "conceded": [
            "Oh~ Not bad!",
            "Hmph, just missed a beat.",
            "You got lucky!",
        ],
        "losing": [
            "The climax hasn't come yet!",
            "Wind Music Boy doesn't back down!",
        ],
        "winning": [
            "Time for the finale~!",
            "You can't keep up with my rhythm!",
        ],
        "match_point": [
            "This is the last verse!",
            "Let me crown the finale!",
        ],
        "in_danger": [
            "The show goes on till the end!",
            "There's still an encore left!",
        ],
    },
    2: {
        "battle_start": [
            "The king of the jungle will face you!",
            "Can you survive this swamp!",
            "Charge! Attack!",
        ],
        "scored": [
            "This is the law of the jungle!",
            "Feel my fangs!",
            "Haha! Pathetic!",
        ],
        "conceded": [
            "Grr... Not bad.",
            "Just a scratch!",
            "Playing tricks, are we!",
        ],
        "losing": [
            "General Croc never retreats!",
            "The jungle king losing... Impossible!",
        ],
        "winning": [
            "Hahaha! This is the difference in skill!",
            "You can't escape the jungle!",
        ],
        "match_point": [
            "Final charge!",
            "I'll end this with one strike!",
        ],
        "in_danger": [
            "Crocodiles are strongest when cornered!",
            "Don't underestimate me!",
        ],
    },
    3: {
        "battle_start": [
            "You'll play with me... right?",
            "Don't run away... please...",
            "Hehe... Let's begin.",
        ],
        "scored": [
            "Hehe... Did that hurt?",
            "Don't hate me... I'll hurt you more.",
            "Fall prettily like a doll...",
        ],
        "conceded": [
            "Why... why are you hitting me...",
            "It hurts... it hurrrts...",
            "No... you're mean...!",
        ],
        "losing": [
            "Are you... going to abandon me...?",
            "You can't do that... you caaaan't...",
        ],
        "winning": [
            "Hehehe... Now you're mine.",
            "You can't escape... forever...",
        ],
        "match_point": [
            "It's over... let's go together...",
            "Together forever... hehe.",
        ],
        "in_danger": [
            "Don't leave meeeee...!",
            "I don't... want it to end yet...",
        ],
    },
    4: {
        "battle_start": [
            "True training begins now.",
            "Maintain your composure.",
            "Om... Mani Padme Hum...",
        ],
        "scored": [
            "This too is part of training.",
            "The path to enlightenment is harsh.",
            "Your training is lacking.",
        ],
        "conceded": [
            "My enlightenment was lacking.",
            "Hmm... A good lesson.",
            "Training lies within suffering.",
        ],
        "losing": [
            "Only worldly desires waver.",
            "True enlightenment comes from hardship.",
        ],
        "winning": [
            "Inner peace leads to victory.",
            "The fruits of training are showing.",
        ],
        "match_point": [
            "The final trial. Stay diligent.",
            "The moment of nirvana approaches.",
        ],
        "in_danger": [
            "Let go of attachment and find the way.",
            "Training is not yet over.",
        ],
    },
    5: {
        "battle_start": [
            "Battle stations. Commence fire.",
            "I am the master of these seas.",
            "Sonar scan complete. Sinking you now.",
        ],
        "scored": [
            "Proceeding as planned.",
            "Hit. Moving to next target.",
            "There is no escape route.",
        ],
        "conceded": [
            "Within expected parameters.",
            "Minor damage. Continuing combat.",
            "Adjusting counterattack coordinates.",
        ],
        "losing": [
            "Reorganizing strategy.",
            "Initiating operation to turn the tide.",
        ],
        "winning": [
            "The encirclement is closing in.",
            "Your chance to retreat has passed.",
        ],
        "match_point": [
            "Final bombardment ready.",
            "Countdown to sinking initiated.",
        ],
        "in_danger": [
            "Nemesis does not sink.",
            "Still have secret firepower remaining.",
        ],
    },
    6: {
        "battle_start": [
            "Feel the flames of Crimson Lotus!",
            "Into the blazing inferno!",
            "Turn to ashes!",
        ],
        "scored": [
            "Burn in the flames!",
            "Turn to cinders!",
            "The flames of Crimson Lotus never stop!",
        ],
        "conceded": [
            "This won't put me out!",
            "Hmph... The embers remain!",
            "I'll only burn hotter!",
        ],
        "losing": [
            "Even extinguished flames reignite!",
            "I'll show you hellfire!",
        ],
        "winning": [
            "I'll burn everything down!",
            "You can't escape the flames!",
        ],
        "match_point": [
            "The final hellfire!",
            "It ends in the ashes!",
        ],
        "in_danger": [
            "Crimson Lotus never fades!",
            "Let me light the last flame!",
        ],
    },
    7: {
        "battle_start": [
            "Game start. Level 1 loaded.",
            "Final defense protocol activated.",
            "Optimizing block placement...",
        ],
        "scored": [
            "Puzzle complete.",
            "Line clear!",
            "As calculated.",
        ],
        "conceded": [
            "...Recalculating.",
            "Misblock. Rearranging.",
            "Correcting error...",
        ],
        "losing": [
            "Difficulty increased.",
            "Applying new algorithm...",
        ],
        "winning": [
            "Game over is approaching.",
            "Perfect block placement.",
        ],
        "match_point": [
            "This is the last block.",
            "One line to Tetris.",
        ],
        "in_danger": [
            "Emergency protocol activated.",
            "...I still have the T-spin.",
        ],
    },
    8: {
        "battle_start": [
            "...The shadow judges.",
            "Hiding is useless.",
            "I'll show you the depths of ninjutsu.",
        ],
        "scored": [
            "You cannot avoid the shadow.",
            "...An unseen strike.",
            "Mission in progress.",
        ],
        "conceded": [
            "...Interesting.",
            "Mistakes won't be repeated.",
            "Next time, not even a shadow will remain.",
        ],
        "losing": [
            "...I'll show you true ninjutsu.",
            "I still have hidden techniques.",
        ],
        "winning": [
            "The outcome is already clear.",
            "You cannot escape the shadow.",
        ],
        "match_point": [
            "The final jutsu.",
            "...It's over.",
        ],
        "in_danger": [
            "A ninja fights to the very end.",
            "Awakening still remains.",
        ],
    },
}

# ── 보스 변형 영문 번역 ──
BOSS_VARIANT_EN = {
    (1, "포도대장"): {
        "battle_start": [
            "I am the Captain of the Guard! Come at me!",
            "By royal decree, I've come to capture you!",
            "Stand back... as if you would!",
            "Behold the authority of the Guard!",
        ],
        "scored": [
            "One command and you can't move!",
            "Haha! This is the Guard's skill!",
            "Hey you! Where do you think you're running!",
            "Break the law and this is what happens!",
        ],
        "conceded": [
            "Hmm... I let my guard down.",
            "Hmph! A fluke!",
            "Not bad... but there won't be a next time!",
            "Insolent! You dare mock me!",
        ],
        "losing": [
            "The Captain losing... Unthinkable!",
            "The Captain defeated! How shameful!",
        ],
        "winning": [
            "I'll bind you and throw you in the dungeon!",
            "No more struggling!",
        ],
        "match_point": [
            "The final rope! Prepare yourself!",
            "Surrender peacefully!",
        ],
        "in_danger": [
            "The Captain never backs down!",
            "My honor is at stake!",
        ],
    },
    (1, "각시탈"): {
        "battle_start": [
            "Hehehe! Let's play~!",
            "What's behind this mask? Guess~!",
            "The clown is here, let the festival begin~!",
        ],
        "scored": [
            "Ooh~ Got you! Hehehe!",
            "I was laughing behind the mask~!",
            "Oh dear, fooled again~!",
        ],
        "conceded": [
            "Oops, shouldn't have done that trick!",
            "Oh no! My mask went crooked~!",
            "Heh heh, one more round~?",
        ],
        "losing": [
            "Hehe, losing is fun too~!",
            "Hmm~ Gotta switch masks!",
        ],
        "winning": [
            "Hehehe! The clown always wins~!",
            "Take a breeze~ Fan wind~!",
        ],
        "match_point": [
            "Last mask change! Watch closely~!",
            "Hehehe! This game is the last~!",
        ],
        "in_danger": [
            "What?! A clown can't lose!",
            "Gotta turn it around before the mask breaks~!",
        ],
    },
    (2, "두더지왕"): {
        "battle_start": [
            "The king of the underground kingdom himself!",
            "I'll tear you apart with these claws!",
            "A surface dweller dares... I'll dig you up!",
            "The Mole King's claws cut through anything!",
        ],
        "scored": [
            "Kahaha! This is the underground king's power!",
            "Feel my claws! How about that!",
            "Weak for a surface dweller!",
        ],
        "conceded": [
            "Grr... Rather sharp!",
            "The underground king, bested by this!",
            "I'll let that one slide... no more!",
        ],
        "losing": [
            "The Mole King pushed back... Impossible!",
            "My claws... aren't working?!",
        ],
        "winning": [
            "Kahaha! Surface dwellers are nothing!",
            "I'll drag you to the underground kingdom!",
        ],
        "match_point": [
            "Final strike! Full power claws!",
            "I'll bury you with this one!",
        ],
        "in_danger": [
            "The Mole King is stronger when cornered!",
            "It's not over yet! I'll dig deeper!",
        ],
    },
}

# ── 영웅 대사 영문 번역 ──
HERO_EN = {
    "mugen": {
        "battle_start": ["...I'll cut you down.", "The blade weeps.", "Your fate ends here."],
        "scored": ["Pathetic.", "...An obvious result.", "Darkness has consumed you."],
        "conceded": ["...Hmph.", "There won't be a next time.", "Not bad."],
        "losing": ["...This is getting interesting.", "My blade awakens.", "It's not over yet.", "...I won't rot in this darkness."],
        "winning": ["The match is already over.", "The shadow will consume you.", "Give up.", "...Win and I can leave. That's all."],
        "deuce": ["Fate is crossing paths.", "In the darkness... it splits."],
        "match_point": ["The final strike.", "...I'll show you the end."],
        "in_danger": ["I haven't dropped my blade yet.", "Darkness doesn't fade easily.", "...This blade won't end here."],
        "retort": ["...Is that all?", "Nonsense.", "How amusing."],
        "round_win": ["...The blade opened the path.", "Darkness has prevailed.", "An expected outcome."],
        "round_lose": ["...The blade hasn't broken yet.", "Next time, I'll cut you down.", "I'll remember this defeat."],
    },
    "kraken": {
        "battle_start": ["...I'm hungry.", "My tentacles are trembling... hehe.", "Let me show you the taste of the deep."],
        "scored": ["Nom... Delicious.", "The tentacles are pleased.", "More... give me more."],
        "conceded": ["Grrrr... That hurts.", "The prey fights back.", "...Unpleasant."],
        "losing": ["I'll show you the deep sea's fury.", "The prey got stronger... hehe.", "More tentacles are reaching out.", "No matter how much I eat here, I'm never full..."],
        "winning": ["Already wrapped in my tentacles.", "You can't escape... hehehe.", "You'll make a tasty meal."],
        "deuce": ["Hehe... Almost caught but not quite.", "The deep sea fog thickens..."],
        "match_point": ["One last bite... nom.", "You can't escape the tentacles."],
        "in_danger": ["I'll drag you into the deep.", "I'm still hungry...", "Gold, whatever... I'll swallow everything."],
        "retort": ["Grrrr... Noisy.", "Shall I eat that mouth first?", "The prey chatters."],
        "round_win": ["Nom... That was a tasty meal.", "The tentacles are satisfied... hehe.", "The deep sea food chain never changes."],
        "round_lose": ["Grrrr... I'm still hungry...", "Bested by prey...", "Next time I'll swallow you whole."],
    },
    "chronos": {
        "battle_start": ["Hoho... An interesting toy.", "Let me show you the power of dark magic.", "You dare challenge this witch?"],
        "scored": ["An obvious result, hoho.", "Powerless before magic.", "Struggle a bit more."],
        "conceded": ["...Insolent.", "You were merely lucky.", "Hmph, a minor mistake."],
        "losing": ["I'll show you true dark magic.", "You'll regret this.", "I won't tolerate this humiliation.", "Being a spectacle here... I won't allow it."],
        "winning": ["As expected, no match for this witch.", "Hoho, the game is already over.", "Feel the difference in magic?"],
        "deuce": ["Hmph... Persistent.", "I need to draw more magic power."],
        "match_point": ["It's over, hoho.", "Let me chant the final spell."],
        "in_danger": ["Kirke... losing?", "I still have forbidden magic left.", "I can break through this world's code..."],
        "retort": ["Hoho... Don't make me laugh.", "All talk, no bite?", "Petty bravado."],
        "round_win": ["Hoho, kneeling before magic.", "An expected result.", "No match for this witch."],
        "round_lose": ["This humiliation... unforgivable.", "Hmph, next time I'll show real dark magic.", "You were merely lucky...!"],
    },
    "onimaru": {
        "battle_start": ["This will be a great sparring match!", "I'll show you the power of my horns!", "I stake my warrior's soul!", "Haha! Second time here? Feels like home!"],
        "scored": ["This is the power of the Oni warrior!", "Good! The momentum rises!", "An Oni's strike!"],
        "conceded": ["Grr... That was a good hit!", "You have skill!", "A warrior falls but rises again!"],
        "losing": ["Unyielding spirit!", "The real fight starts now!", "My horns grow harder!", "Got even stronger after going out and coming back!"],
        "winning": ["Kneel before the Oni's power!", "The path to victory is clear!", "This is the strength forged in hell!", "It's more fun here than outside! Haha!"],
        "deuce": ["Evenly matched! Good!", "This is the kind of fight worth living for!"],
        "match_point": ["Take the final blow!", "I'll finish this match!"],
        "in_danger": ["A warrior never retreats!", "I came from hell, I fear nothing!", "Think someone who came back after release would lose?!"],
        "retort": ["Ha! We'll see!", "You think that'll break this Oni?", "I'm not interested in words!"],
        "round_win": ["Hahaha! A satisfying victory!", "This is the Oni warrior's power!", "That was a good fight!"],
        "round_lose": ["Grr... Next time, for sure!", "I'll fight until these horns break!", "That was a good match... I acknowledge it!"],
    },
    "maria": {
        "battle_start": ["The dolls... want to play.", "Hehe, let's play~", "I'll weave the strings... hoho."],
        "scored": ["The dolls are happy~", "Hehe, fun~", "The strings are getting tighter."],
        "conceded": ["...Ow. The dolls are crying.", "Bad child... I'll punish you.", "Hehe... I'm angry."],
        "losing": ["The dolls are angry.", "I'll bring out the scary dolls.", "The play isn't over yet.", "If I get out... can I really play with dolls..."],
        "winning": ["Hehe, the dolls are dancing~", "Caught in the strings... can't escape.", "This play... the end is near~"],
        "deuce": ["Hehe... It's even.", "The dolls are nervous too..."],
        "match_point": ["The last puppet show... hehe.", "I'll cut the strings~"],
        "in_danger": ["The dolls are crying... no...", "Still... strings remain.", "Logout... what was that... hehe."],
        "retort": ["Hehe... Funny sounds~", "The dolls are mocking you.", "Say what you want... the strings won't come loose."],
        "round_win": ["Hehe~ Puppet show's over~", "You were the one caught in strings.", "The dolls are celebrating~"],
        "round_lose": ["...The dolls are crying.", "Next time I'll bring scarier dolls.", "The play isn't over..."],
    },
    "ignis": {
        "battle_start": ["I'll light the way with flames!", "This blade blessed by the dragon!", "Blazing! Are you ready!"],
        "scored": ["The flames are burning!", "This is a dragon knight's strike!", "Hot, right? Haha!"],
        "conceded": ["Grr... Not yet!", "Flames don't go out!", "Good hit, but!"],
        "losing": ["The flames grow stronger!", "Taste the dragon's fury!", "I'll never give up!", "If this flame dies, I'll never get out...!"],
        "winning": ["Haha! This is the dragon's power!", "Everything burns before the flames!", "The flame of victory is in sight!"],
        "deuce": ["A fiery match! Great!", "Flame against flame!"],
        "match_point": ["The final breath!", "I'll finish you with flames!"],
        "in_danger": ["A dragon knight fights even in fire!", "Embers still remain!", "If I lose here... my sentence only grows!"],
        "retort": ["That spirit isn't enough!", "Nonsense before the flames!", "Ha! What a joke!"],
        "round_win": ["Victory of the flames! Haha!", "Did you see the dragon's power!", "Blaze! Burn bright!"],
        "round_lose": ["Grr... Embers never die!", "Next time I'll burn you with my breath!", "This won't break a dragon knight!"],
    },
    "gear": {
        "battle_start": ["Gear condition perfect today! Let's go!", "Hoho, wanna see my latest creation?", "Steam charged~! Shall we race!"],
        "scored": ["My machines are the best!", "This gear setting is perfect!", "Hoho, what I build never misses!"],
        "conceded": ["Ugh, what was that...!", "Hmm... needs some maintenance?", "Grr, won't happen again!"],
        "losing": ["I won't give up this easily!", "Let me crank up the steam pressure!", "Don't mock my machines!", "First thing I'll do when I get out is hit my workshop...!"],
        "winning": ["Hoho~ My inventions are shining!", "Isn't this a great success?", "The gears are running perfectly!"],
        "deuce": ["Ugh, so close...!", "Here's where it gets real!"],
        "match_point": ["Turning the last gear...!", "Full power! I'll finish this!"],
        "in_danger": ["This can't be happening...! Focus!", "Emergency! Full power!", "What's so great about maritime security...!"],
        "retort": ["Hmph, don't talk about my machines that way!", "Words can't stop gears!", "Try it yourself before talking!"],
        "round_win": ["My machines are the best!", "Hoho~ Perfect setup!", "Full gear activation success!"],
        "round_lose": ["Ugh... needs maintenance...", "Next time with new gears!", "This won't stop me!"],
    },
    "kurokage": {
        "battle_start": ["...Mission start.", "Shadows move without sound.", "Your weakness is already known."],
        "scored": ["Mission in progress.", "...Precise.", "Shadow's strike."],
        "conceded": ["...Mistakes won't be repeated.", "Hmph.", "There won't be a next time."],
        "losing": ["...I'll unleash the forbidden.", "The shadow grows darker.", "A ninja completes the mission to the end.", "...Sentences mean nothing. There are no prisons for shadows."],
        "winning": ["A predetermined result.", "You can't escape the shadow.", "Mission completion approaches."],
        "deuce": ["...Evenly matched.", "The boundary of shadow and light."],
        "match_point": ["The last shadow.", "...I'll end this."],
        "in_danger": ["A ninja doesn't run.", "Before the shadow fades...", "...If this world needs a ninja, I'll stay."],
        "retort": ["...Noisy.", "Shadows need no words.", "...All bluster."],
        "round_win": ["...Mission complete.", "Shadows don't disappear.", "A predetermined result."],
        "round_lose": ["...Until the next mission.", "Shadows don't lose. They just hide.", "...Training was lacking."],
    },
    "banshee": {
        "battle_start": ["...Let me release this grudge.", "Your soul is weeping.", "A cold wind blows..."],
        "scored": ["Hoho... Can you hear it? My scream.", "One more soul.", "...Cold, isn't it?"],
        "conceded": ["...Oh my.", "Ghosts don't die.", "Hmph, it doesn't hurt."],
        "losing": ["...Rage is building.", "The deeper the grudge, the stronger I become.", "I'll repay this resentment...", "Reality awaits... I can't end here."],
        "winning": ["Your soul is mine.", "The curse has already begun.", "Hohoho..."],
        "deuce": ["A crossroads of fate...", "Between the world of the living and the dead..."],
        "match_point": ["I'll let you hear the final scream.", "...Farewell."],
        "in_danger": ["Ghosts don't disappear...!", "The grudge holds me here...", "I'm not the only one trapped in this world."],
        "retort": ["...Quiet. I'm louder.", "The bravado of the living is fleeting.", "Hoho... How pitiful."],
        "round_win": ["Hohoho... Your soul is mine.", "The screams were beautiful.", "A cold victory... not bad."],
        "round_lose": ["Ghosts don't disappear...", "The grudge only deepens...", "Next time I'll place a curse."],
    },
    "necro": {
        "battle_start": ["The souls are calling...", "Death is not the end.", "Let me guide you to the underworld."],
        "scored": ["One soul harvested.", "The touch of death has reached you.", "...Another soul."],
        "conceded": ["Hmm... Still alive.", "Death is not in a hurry.", "Soon... Soon."],
        "losing": ["More souls are needed.", "Awakening the army of death...", "The game isn't over yet.", "Eternal life... that's why I hacked this place."],
        "winning": ["The soul is already departing.", "Time to rest in death's embrace.", "The gates of the underworld open..."],
        "deuce": ["The boundary of life and death...", "The soul is splitting."],
        "match_point": ["Your last breath.", "The reaper awaits..."],
        "in_danger": ["Death doesn't come easily.", "The soul is still mine.", "How long since I couldn't log out...?"],
        "retort": ["...Useless struggle.", "The living's nonsense.", "Be silent."],
        "round_win": ["One more soul harvested.", "Congratulations on resting in death's embrace.", "The gates of the underworld have opened..."],
        "round_lose": ["Death is not in a hurry...", "The soul is still mine.", "Next time... I'll definitely reap."],
    },
    "joker": {
        "battle_start": ["The show has begun!", "Haha! Let's play a fun game!", "Surprise~ Ready?"],
        "scored": ["Hahaha! Ta-da~!", "Surprise~!", "Wrong! Fooled you again?"],
        "conceded": ["Oh? Not bad~?", "Haha, you got lucky!", "Hmm... That's part of the show!"],
        "losing": ["Oh~ Is the audience angry?", "Haha... I still have a trump card!", "The show isn't over yet!", "The casino clown can't lose~!"],
        "winning": ["So~ What's the next trick~?", "Hahaha! This is too easy!", "Applause~! Applause~!"],
        "deuce": ["Oho~ This is thrilling?", "Ladies and gentlemen~ The climax!"],
        "match_point": ["Finale~ Ready!", "The last surprise!"],
        "in_danger": ["Haha... Still laughing, you see?", "A clown never cries!", "The audience is watching~ Let's make it grand!"],
        "retort": ["Haha! So serious~", "That's your best? Hilarious~", "Boring joke~"],
        "round_win": ["Today's show was a great success!", "Hahaha! Applause~!", "Surprise~ I won!"],
        "round_lose": ["Haha... Shows sometimes fail!", "The next trick will be even better~", "That's part of the show too! ...Probably."],
    },
    "mirage": {
        "battle_start": ["The desert mirage will engulf you...", "Find the truth in the sandstorm.", "Illusion and reality... can you tell them apart?"],
        "scored": ["Sand does not lie.", "Deceived by the mirage...", "The desert's judgment."],
        "conceded": ["Intriguing... You saw through the illusion.", "Even sandstorms settle sometimes..."],
        "losing": ["The desert night is still long...", "Secrets remain hidden in the sand.", "This world itself is a mirage... there's a way out."],
        "winning": ["This is the desert's providence.", "None can escape the sandstorm.", "The illusions haven't even begun..."],
        "deuce": ["At the boundary of mirage and reality...", "The hourglass has been flipped again."],
        "match_point": ["The last grain of sand falls...", "Time for the desert's judgment."],
        "in_danger": ["The sandstorm never stops...", "The desert opens the way for the patient.", "Virtual or real... the sand flows."],
        "retort": ["In the desert, loud voices are buried in sand.", "Just words carried by the wind...", "Another one fooled by illusions."],
        "round_win": ["As the desert's providence dictates.", "After the mirage clears... one victor remains.", "The hourglass was on my side."],
        "round_lose": ["The sandstorm will blow again...", "The desert opens the way for the patient.", "This too is merely a mirage..."],
    },
    "ra": {
        "battle_start": ["The eyes of lightning see through you.", "Thunder roars where my wings pass.", "The hawk of the sky descends with thunder."],
        "scored": ["The judgment of the lightning bolt.", "There's no hiding from lightning.", "A bolt crashes down from the sky."],
        "conceded": ["The thundercloud merely missed...", "Hmph, the hawk's eye doesn't tolerate mistakes..."],
        "losing": ["The storm never sleeps forever.", "Thunder will always roar again.", "Don't look down on a hawk caged here."],
        "winning": ["This is the majesty of the thunder god.", "All is revealed before the lightning's judgment.", "The result from atop the throne of thunderclouds."],
        "deuce": ["Balance wavers in the eye of the storm...", "As thunder and silence divide the sky..."],
        "match_point": ["The final bolt strikes down.", "The spear of thunder cleaves the earth."],
        "in_danger": ["Even if the clouds clear... lightning is lightning.", "The fiercer the storm, the closer the bolt.", "This cage... I'll shatter it with lightning."],
        "retort": ["The chirping of an insect.", "A bug chatters before lightning?", "Speak while looking up at the sky."],
        "round_win": ["The thunder god's judgment has fallen.", "There was no hiding from lightning.", "The hawk of the sky claims victory."],
        "round_lose": ["The storm merely pauses...", "Lightning will surely strike again.", "The hawk's eye... targets the next."],
    },
    "monkeyking": {
        "battle_start": ["Ooh-ki-ki-ki!!", "Oo-ki-ki oo-ki!!", "Ki-ki-kii!!"],
        "scored": ["Oo-ki-ki~!", "Oo-ki! Oo-ki-ki!", "Ki-ki! Ki-kii!"],
        "conceded": ["Ki...ki-ik...", "Oo-ki...", "Ki-kii...!"],
        "losing": ["Oo-ki-ki-ki-ki-ki!!", "Ki-iii-ik!!", "Oo-kii!! Oo-ki-ki!!", "Oo-ki... ki-ki... ki......"],
        "winning": ["Oo-ki-ki~♪", "Oo-ki-ki-ki!", "Ki-ki! Ki-ki-ki!"],
        "deuce": ["Oo-ki...ki-ki...!", "Ki-kii...oo-ki!"],
        "match_point": ["Oo-ki-ki-ki-ki!!!", "Ki-iii-iii-ik!!!"],
        "in_danger": ["Ki...ki-ki-ki!!", "Oo-ki-ki!! Oo-kii!!", "Ki-i...ki-ii..."],
        "retort": ["Oo-ki!", "Ki-kii!!", "Oo-ki-ki!"],
        "round_win": ["Oo-ki-ki~!! Oo-ki-ki~♪", "Ki-ki! Ki-ki-ki-ki!", "Oo-kii~! Oo-ki-ki!"],
        "round_lose": ["Ki...ki-ii...", "Oo-ki... oo-kii......", "Ki-ki-kii..."],
    },
    "android": {
        "battle_start": ["Combat mode activated.", "Scan complete. ...Prepare yourself.", "Excitement...? No circuit anomaly."],
        "scored": ["Point scored. ...Should I be happy?", "Hit confirmed. Simulating pride.", "Success. ...Is this correct?"],
        "conceded": ["Damage taken. ...Is this frustration?", "Point lost. Tear function not installed.", "[Warning] Simulating embarrassment..."],
        "losing": ["Disadvantage. Giving up... is not an option?", "Win rate declining. ...Continuing to the end.", "Gritting teeth. Though I have none.", "Cannot log out. ...Return destination unknown."],
        "winning": ["Advantage. Should I smile?", "Win rate 87.3%. ...Is this confidence?", "Attempting to express composure."],
        "deuce": ["Tied. Heartbeat... not applicable.", "Even match. Processing tension..."],
        "match_point": ["Final phase. ...Is this resolve?", "Performing last computation. No trembling."],
        "in_danger": ["Danger rising. ...Fear? Unknown value.", "Defeat probability increasing. Cannot stop.", "Remaining sentence: Unknown."],
        "retort": ["...Intent analysis failed.", "Provocation. No effect.", "...Illogical."],
        "round_win": ["Victory. ...Attempting to express joy.", "Mission complete. No anomaly.", "Win rate updated. ...Is this pride?"],
        "round_lose": ["Defeat. ...Sadness? Unknown value.", "Retry request. Denied.", "Next computation... I will win."],
    },
}

# ── 호위 영웅 광장 대사 영문 번역 ──
IDLE_EN = {
    "mugen": [
        "...The blade is an extension of my soul.",
        "Darkness lurks in this plaza too.",
        "I'll watch your back.",
        "The wind is cold... Smells like the battlefield.",
        "Don't waste your words.",
    ],
    "kraken": [
        "...I miss the deep sea.",
        "The air here is too dry.",
        "My tentacles are itching...",
        "Is it just me or do I smell prey?",
        "Let's go somewhere with water.",
    ],
    "chronos": [
        "Hehe... Interesting place.",
        "I can feel magical energy.",
        "A good day for chanting spells.",
        "Be careful, curses are everywhere.",
        "Today's fortune isn't looking good.",
    ],
    "onimaru": [
        "Kahaha! Anyone to fight?",
        "My horns are itching...",
        "A peaceful place like this isn't bad.",
        "I could use a drink.",
        "Nothing but weaklings...",
    ],
    "maria": [
        "The dolls are whispering...",
        "This plaza would make a perfect stage.",
        "Is someone talking to me...?",
        "Hoho... Lots of interesting people.",
        "Careful, or you'll become a doll.",
    ],
    "ignis": [
        "The dragon's flame is burning!",
        "I drew my blade for honor.",
        "This armor is a bit hot though...",
        "Courage is overcoming fear.",
        "It's an honor to fight alongside you.",
    ],
    "gear": [
        "Look at these gears! Perfect!",
        "I just got a new invention idea!",
        "Time to check the steam engine.",
        "I want to open a workshop in this plaza...",
        "Machines never betray you.",
    ],
    "kurokage": [
        "....",
        "Enemies hide in the shadows.",
        "Quiet your footsteps.",
        "A ninja needs no words.",
        "...Watch your back.",
    ],
    "banshee": [
        "A wind from the underworld blows...",
        "Want to hear my scream...?",
        "Being a ghost isn't bad.",
        "This world is too noisy.",
        "I prefer cold places...",
    ],
    "necro": [
        "The skeletons want to say hello.",
        "Death is not the end, it's the beginning.",
        "Something is buried under this plaza.",
        "I miss my throne of bones.",
        "Hoho... I see an interesting soul.",
    ],
    "joker": [
        "Hahaha! What a fun place!",
        "Surprise~ Look forward to it!",
        "A clown must always smile!",
        "Want to draw a card?",
        "I can't stand boredom!",
    ],
    "mirage": [
        "Shall I show you a desert mirage?",
        "It's time for the sandstorm to blow.",
        "The line between illusion and reality... blurry.",
        "This plaza might be a mirage too.",
        "Are you really... you?",
    ],
    "android": [
        "[System operating normally]",
        "[Alert mode activated]",
        "[Analyzing combat data...]",
        "[Emotion module... error]",
        "[Escort mission in progress]",
    ],
    "ra": [
        "The power of lightning is rising!",
        "With the hawk's eyes, I see everything.",
        "May the sun god's blessing be with you.",
        "A day I want to fly in the sky.",
        "I miss the sound of thunder...",
    ],
    "monkeyking": [
        "Oo-ki-ki! This place is fun!",
        "Got any bananas? I'm hungry!",
        "Treetops are more comfortable...",
        "Anyone wanna fight!",
        "I miss the jungle... oo-ki.",
    ],
}

# 기본 대사 번역
DEFAULT_EN = [
    "...",
    "Keeping watch.",
    "Good to have company.",
    "Ready at any time.",
    "A quiet day.",
]


def build_json_entries():
    """모든 대사의 ko/en JSON 엔트리를 생성"""
    ko_entries = {}
    en_entries = {}

    # ─── 1. 보스 대사 (BOSS_DIALOGUES) ───
    # 원본 한국어 데이터 가져오기
    import sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from downtown.boss_dialogues import BOSS_DIALOGUES, BOSS_VARIANT_DIALOGUES
    from downtown.hero_dialogues import HERO_DIALOGUES
    from downtown.bodyguard_follower import HERO_IDLE_DIALOGUES, DEFAULT_DIALOGUES

    for stage, situations in BOSS_DIALOGUES.items():
        for sit, lines in situations.items():
            for idx, line in enumerate(lines):
                key = f"bdlg.{stage}.{sit}.{idx}"
                ko_entries[key] = line
                en_entries[key] = BOSS_EN[stage][sit][idx]

    # ─── 2. 보스 변형 대사 (BOSS_VARIANT_DIALOGUES) ───
    variant_key_map = {
        "포도대장": "podo",
        "각시탈": "gaksi",
        "두더지왕": "mole",
    }
    for (stage, boss_name), situations in BOSS_VARIANT_DIALOGUES.items():
        vkey = variant_key_map.get(boss_name, boss_name)
        for sit, lines in situations.items():
            for idx, line in enumerate(lines):
                key = f"bdlg.{stage}.v_{vkey}.{sit}.{idx}"
                ko_entries[key] = line
                en_entries[key] = BOSS_VARIANT_EN[(stage, boss_name)][sit][idx]

    # ─── 3. 영웅 대사 (HERO_DIALOGUES) ───
    for hero_id, situations in HERO_DIALOGUES.items():
        for sit, lines in situations.items():
            for idx, line in enumerate(lines):
                key = f"hdlg.{hero_id}.{sit}.{idx}"
                ko_entries[key] = line
                en_entries[key] = HERO_EN[hero_id][sit][idx]

    # ─── 4. 호위 광장 대사 (HERO_IDLE_DIALOGUES) ───
    for hero_id, lines in HERO_IDLE_DIALOGUES.items():
        for idx, line in enumerate(lines):
            key = f"idlg.{hero_id}.{idx}"
            ko_entries[key] = line
            en_entries[key] = IDLE_EN[hero_id][idx]

    # ─── 5. 기본 대사 (DEFAULT_DIALOGUES) ───
    for idx, line in enumerate(DEFAULT_DIALOGUES):
        key = f"idlg.default.{idx}"
        ko_entries[key] = line
        en_entries[key] = DEFAULT_EN[idx]

    return ko_entries, en_entries


def merge_into_json(filepath, new_entries):
    """기존 JSON에 새 엔트리를 병합"""
    with open(filepath, "r", encoding="utf-8") as f:
        data = json.load(f)

    data.update(new_entries)

    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    return len(new_entries)


if __name__ == "__main__":
    ko_entries, en_entries = build_json_entries()

    ko_path = os.path.join(os.path.dirname(__file__), "localization", "ko.json")
    en_path = os.path.join(os.path.dirname(__file__), "localization", "en.json")

    ko_count = merge_into_json(ko_path, ko_entries)
    en_count = merge_into_json(en_path, en_entries)

    print(f"ko.json: {ko_count} entries added")
    print(f"en.json: {en_count} entries added")
    print(f"Total keys: boss={sum(1 for k in ko_entries if k.startswith('bdlg.'))}, "
          f"hero={sum(1 for k in ko_entries if k.startswith('hdlg.'))}, "
          f"idle={sum(1 for k in ko_entries if k.startswith('idlg.'))}")
