import MuseScore 1.0

MuseScore {

    version: "1.0";
    description: "This demo plugin adds new chords\n\n" +
                 "Comments, feedbacks, report bugs, ask for new features, contribute:\n" +
                 "https://musescore.org/en/project/chordidentifier";
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
        chord_notes=rm_dup(chord_notes);
        var cur_time=cursor.tick;
        cursor.setDuration(1, duration);
        cursor.addNote(chord_notes[0]); //add 1st note
        setCursorToTime(cursor, cur_time); //rewind to this note
        var chord = cursor.element; //get the chord created when 1st note was inserted
        for(var i=1; i<chord_notes.length; i++){
            chord.add(createNote(chord_notes[i])); //add notes to the chord
        }
        cursor.next();
        return 0;
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
        cursor.track = 0;
        
        
        
        // ------------------ GENERATE CHORDS ----------------
        addChord(cursor, [60, 64, 64, 67], 8);
        
        var chord2 = [62, 65, 69, 71];
        addChord(cursor, chord2, 8);
        addChord(cursor, chord2, 8);
        // ----------------------------------


        Qt.quit();
    } // end onRun
}