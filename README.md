# Plugins for Musescore

<h3>Chord Identifier Plugin:</h3>
- Identify chords and put chord symbol on top.
- Works with single or multiple voices, accross one or more staves (like in sheet music for piano).
- Inversions are indicated.
- Notes are colored according to their function in the chord:
	* Root in green
	* Third in brown
	* Seventh in red
- Works on whole sheet or on selected portion.
- Shows chords used in classical music: triads (major, minor, diminished) and seventh chords (MM7, m7, Mm7, dim7).<br/>

Note: Chord symbols are put in chord symbol text element (!), and the plugin can be run multiple times without texts fields being duplicated! (was not the case in other plugins)

<h3>Example:</h3>
<img height="150px" src="https://raw.githubusercontent.com/rousselmanu/msc_plugins/master/example_standard.png"/>

With "Jazz" style (go to "Style" menu):<br/>
<img height="150px" src="https://raw.githubusercontent.com/rousselmanu/msc_plugins/master/example_jazz.png"/>

<h3>Installation:</h3>
Plugins are for Musescore 2.0
- Put the plugin (.qml) in the MuseScore/plugins folder (basically "C:/users/%USERNAME%/Documents/MuseScore2/Plugins" in Windows)
- Restart MuseScore
- Enable the plugin in "Plugin Manager" (you can also associate a shortcut)

More info: https://musescore.org/en/handbook/plugins

<h3>Acknowledgment:</h3>
I started this plugin as an improvement of the "Find Harmonies" plugin by Andresn
	(https://github.com/andresn/standard-notation-experiments/tree/master/MuseScore/plugins/findharmonies)<br/>
	Itself being an enhanced version of "findharmony" by Merte (http://musescore.org/en/project/findharmony)<br/>
	<br/>
I took some lines of code or got inspiration from:
- Berteh (https://github.com/berteh/musescore-chordsToNotes/)
- Jon Ensminger (AddNoteNameNoteHeads v. 1.2 plugin)

--> Thank you :-)


Comments and feedbacks are welcome!
mail: rousselmanu at gmail.com