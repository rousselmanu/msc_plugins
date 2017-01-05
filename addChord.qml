import MuseScore 1.0

MuseScore {

    version: "1.0";
    description: "This demo plugin adds new chords\n\n" +
                 "Comments, feedbacks, report bugs, ask for new features, contribute:\n" +
                 "https://github.com/rousselmanu/msc_plugins/";
    menuPath: "Plugins.Chords." + qsTr("Add Chord Demo")
    
    // ---------- remove duplicate notes from chord (notes with same pitch) --------
    function rm_dup(chord){
        var chord_notes=new Array();
        if(chord.pitch != null){
            for(var i=0; i<chord.length; i++)
               chord_notes[i] = chord[i].pitch; // remove octaves
        }else{
            chord_notes=chord;
        }
        
        chord_notes.sort(function(a, b) { return a - b; }); //sort notes

        var chord_uniq = chord_notes.filter(function(elem, index, self) {
            return index == self.indexOf(elem);
        }); //remove duplicates

        return chord_uniq;
    }
    
    function rm_octave(chord){
        var chord_notes=new Array();

        if(chord.pitch != null){
            for(var i=0; i<chord.length; i++)
               chord_notes[i] = chord[i].pitch%12; // remove octaves
        }else{
            for(var i=0; i<chord.length; i++)
                chord_notes[i]=chord[i]%12;
        }
        return chord_notes;
    }
    
    function shift_notes(chord, n){
        var shifted_chord=new Array();
        for(var i=0; i<chord.length; i++)
               shifted_chord[i] = chord[i]+n;
           return shifted_chord;
    }
    
    // create and return a new Note element with given (midi) pitch, tpc1, tpc2 and headtype
    function createNote(pitch, tpc1, tpc2, head){
        var note = newElement(Element.NOTE);
        note.pitch = pitch;
        var pitch_mod12 = pitch%12; 
        var pitch2tpc=[14,21,16,23,18,13,20,15,22,17,24,19]; //get tpc from pitch... yes there is a logic behind these numbers :-p
        if (tpc1){
            note.tpc1 = tpc1;
            note.tpc2 = tpc2;
        }else{
            note.tpc1 = pitch2tpc[pitch_mod12];
            note.tpc2 = pitch2tpc[pitch_mod12];
        }
        if (head) note.headType = head; 
        else note.headType = NoteHead.HEAD_AUTO;
        console.log("  created note with tpc: ",note.tpc1," ",note.tpc2," pitch: ",note.pitch);
        return note;
    }
    
    function setCursorToTime(cursor, time){
        cursor.rewind(0);
        while (cursor.segment) { 
            var current_time = cursor.tick;
            if(current_time>=time){
                return true;
            }
            cursor.next();
        }
        cursor.rewind(0);
        return false;
    }
    
    //adds chord at current position. chord_notes is an array with pitch of notes.
    function addChord(cursor, chord_notes, duration){ 
        if(chord_notes.length==0) return -1;
        if(chord_notes.length>1) chord_notes=rm_dup(chord_notes);
        var cur_time=cursor.tick;
        cursor.setDuration(1, duration);
        cursor.addNote(chord_notes[0]); //add 1st note
        var next_time=cursor.tick;
        setCursorToTime(cursor, cur_time); //rewind to this note
        var chord = cursor.element; //get the chord created when 1st note was inserted
        for(var i=1; i<chord_notes.length; i++){
            chord.add(createNote(chord_notes[i])); //add notes to the chord
        }
        setCursorToTime(cursor, next_time);
        return 0;
    }
    
    //note to pitch
    function n2p(note, octave){
        var notenames=['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'];
        var pitch=notenames.indexOf(note);
        if(pitch==-1) return -1;
        pitch+=12*(octave+1);
        //console.log('pitch: '+pitch);
        return pitch;
    }

    onRun: {
        if (typeof curScore === 'undefined') {
            Qt.quit();
        }

        var cursor = curScore.newCursor(),
                startStaff,
                endStaff,
                endTick,
                fullScore = false;
                
        cursor.rewind(1);
        
        if (!cursor.segment) { // no selection
            fullScore = true;
            startStaff = 0; // start with 1st staff
            endStaff = curScore.nstaves - 1; // and end with last
        } else {
            startStaff = cursor.staffIdx;
            cursor.rewind(2);
            if (cursor.tick === 0) {
                // this happens when the selection includes
                // the last measure of the score.
                // rewind(2) goes behind the last segment (where
                // there's none) and sets tick=0
                endTick = curScore.lastSegment.tick + 1;
            } else {
                endTick = cursor.tick;
            }
            endStaff = cursor.staffIdx;
        }
        console.log(startStaff + " - " + endStaff + " - " + endTick);
        console.log('curScore.nstaves: ' + curScore.nstaves);
        console.log('cursor.tick: ' + cursor.tick);
        console.log('curScore.lastSegment.tick: ' + curScore.lastSegment.tick);

        cursor.rewind(1); // beginning of selection
        if (fullScore) { // no selection
            cursor.rewind(0); // beginning of score
        }
        cursor.voice = 0;
        cursor.staffIdx = startStaff; //staff;
        //cursor.track = 0;
        
        // ------------------ GENERATE CHORDS ----------------
        addChord(cursor, [n2p('D',4)], 2); //add a D4 note
        addChord(cursor, [n2p('D',4), n2p('A',4), n2p('D',5), n2p('F',5)], 4); //add a Dm chord with 2 roots
        addChord(cursor, [n2p('A#',3), n2p('D',4), n2p('G',4)], 4);
        addChord(cursor, [n2p('A',3), n2p('G',4), n2p('C#',5)], 4);
        addChord(cursor, [n2p('D',4), n2p('D',5), n2p('F',4), n2p('A',4)], 2);
        addChord(cursor, [62], 1); //other method to add note: give the pitch
        
        addChord(cursor, [60, 65, 69, 72, 69], 8); //duplicate note is automatically removed
        addChord(cursor, [60], 8);
        var chord = [60, 64, 67];
        addChord(cursor, shift_notes(chord,5), 8); //shift the chord by 5 semi-tones
        addChord(cursor, chord, 2);
        // ----------------------------------


        Qt.quit();
    } // end onRun
}