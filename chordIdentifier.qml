//=============================================================================
//  MuseScore - Chord Identifier Plugin
//
//  Copyright (C) 2016 Emmanuel Roussel - https://github.com/rousselmanu/msc_plugins
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License version 2
//  as published by the Free Software Foundation and appearing in
//  the file LICENSE
//
//  Documentation: https://github.com/rousselmanu/msc_plugins
//  Support: https://github.com/rousselmanu/msc_plugins/issues
//  
//  I started this plugin as an improvement of the "Find Harmonies" plugin by Andresn 
//      (https://github.com/andresn/standard-notation-experiments/tree/master/MuseScore/plugins/findharmonies)
//      itself being an enhanced version of "findharmony" by Merte (http://musescore.org/en/project/findharmony)
//  I took some lines of code or got inspiration from:
//  - Berteh (https://github.com/berteh/musescore-chordsToNotes/)
//  - Jon Ensminger (AddNoteNameNoteHeads v. 1.2 plugin)
//  Thank you :-)
//=============================================================================

import QtQuick 2.3
import QtQuick.Controls 1.2
import QtQuick.Dialogs 1.2
import QtQuick.Layouts 1.1
import QtQuick.Controls.Styles 1.3
import MuseScore 1.0

MuseScore {

    version: "1.0";
    description: "- Identify chords and put chord symbol on top.\n" +
                 "- Works with single or multiple voices, accross one or more staves.\n" +
                 "- Inversions are mentionned.\n" +
                 "- Notes are colored according to their function in the chord:\n" +
                 "\t* Root in green\n\t* Third in brown\n\t* Seventh in red\n" +
                 "- Shows only chords used in classical music: triads (major, minor, diminished) and seventh chords (MM7, m7, Mm7, dim7)\n\n" +
                 "Comments, feedbacks, report bugs, ask for new features, contribute:\n" +
                 "https://github.com/rousselmanu/msc_plugins";
    menuPath: "Plugins.Chords." + qsTr("Chord Identifier")
    
    property variant black : "#000000"
    property variant darkred : "#900000"
    property variant darkyellow : "#703030"
    property variant darkgreen : "#005000"
    property variant red : "#ff0000"
    property variant green : "#00ff00"
    property variant blue : "#0000ff"
    
    function getChordName(chord) {
        var rootNote = null,
            inversion = null,
            inversions = ["", "\u00B9", "\u00B2", "\u00B3"], // unicode for superscript "1", "2", "3" (e.g. to represent C Major first, or second inversion)
            chordName = "";
        
        // intervals (number of semitones from root note) for main chords types...
        var chords_type = [ [4,7],  //M
                            [3,7],  //m
                            [3,6],  //dim
                            [4,7,11],   //MM7
                            [3,7,10],   //m7
                            [4,7,10],   //Mm7
                            [3,6,10]];   //dim7
        //... and associated notation:
        var chords_str = ["", "m", "\u00B0", "MM7", "m7", "Mm7", "\u00B07"];
        //get note from TPC (Tonal Pitch Class):
        var tpc_str = ["Cbb","Gbb","Dbb","Abb","Ebb","Bbb",
            "Fb","Cb","Gb","Db","Ab","Eb","Bb","F","C","G","D","A","E","B","F#","C#","G#","D#","A#","E#","B#",
            "F##","C##","G##","D##","A##","E##","B##","Fbb"]; //tpc -1 is at number 34 (last item).

        // ---------- SORT CHORD from bass to soprano --------
        chord.sort(function(a, b) { return (a.pitch) - (b.pitch); }); //bass note is now chord[0]
        
        //debug:
//        for(var i=0; i<chord.length; i++){
//            console.log('pitch note ' + i + ': ' + chord[i].pitch + ' -> ' + chord[i].pitch%12);
//        }   
        
        // ---------- remove duplicate notes from chord (notes with same pitch) --------
        var chord_notes=new Array();
        
        for(var i=0; i<chord.length; i++)
            chord_notes[i] = chord[i].pitch%12; // remove octaves
        
        chord_notes.sort(function(a, b) { return a - b; }); //sort notes
        
        var chord_uniq = chord_notes.filter(function(elem, index, self) {
            return index == self.indexOf(elem);
        }) //remove duplicates
        
        //debug:
        //for(var i=0; i<chord_uniq.length; i++) console.log('pitch note ' + i + ': ' + chord_uniq[i]);

        // ---------- find intervals for all possible positions of the root note ---------- 
        var n=chord_uniq.length;
        var intervals = new Array(n); for(var i=0; i<n; i++) intervals[i]=new Array();
        for(var root_pos=0; root_pos<n; root_pos++){ //for each position of root note in the chord
            var idx=-1;
            for(var i=0; i<n-1; i++){ //get intervals from current "root"
                var cur_inter = (chord_uniq[(root_pos+i+1)%n] - chord_uniq[(root_pos+i)%n])%12;  while(cur_inter<0) cur_inter+=12;
                if(cur_inter != 0){// && (idx==-1 || intervals[root_pos][idx] != cur_inter)){   //avoid duplicates and 0 intervals
                    idx++;
                    intervals[root_pos][idx]=cur_inter;
                    if(idx>0)
                        intervals[root_pos][idx]+=intervals[root_pos][idx-1];
                }
            }
            //debug:
            //console.log('\t intervals: ' + intervals[root_pos]);
        }
        //intervals.sort(function(a, b) { return a - b; });
        
        // ---------- Compare intervals with chord types for identification ---------- 
        for(var idx_chtype=chords_type.length-1; idx_chtype>=0; idx_chtype--){ //chord types. Start from largest one (7th chords)
            for(var root_pos=0; root_pos<n; root_pos++){ //loop through the possible intervals = possible root positions
                //console.log('root_pos: '+root_pos);
                //console.log('\t interval: ' + intervals[root_pos]);
                
                var similar_notes=0;
                for(var idx_inter=0; idx_inter<Math.min(chords_type[idx_chtype].length, intervals[root_pos].length); idx_inter++){ //interval index in the chord
                    if(chords_type[idx_chtype][idx_inter] == intervals[root_pos][idx_inter]){ //if interval is the same
                        similar_notes++;
                    }else{
                        similar_notes=0;
                        break; //not the same chord, exit current loop
                    }
                }
                
                if(similar_notes!=0 && similar_notes==chords_type[idx_chtype].length){ //chord has been identified
                    rootNote=chord_uniq[root_pos];
                    console.log('FOUND CHORD number '+ idx_chtype +'! root_pos: '+root_pos);
                    console.log('\t interval: ' + intervals[root_pos]);
                    break;
                }
            }
            if(rootNote != null) break; //chord found, exit loop.
        }
        
        var chordRootNote;
        if (rootNote !== null) { // ----- the chord was identified
            for(i=0; i<chord.length; i++){  // ---- color notes and find root note
                if((chord[i].pitch%12) == (rootNote%12)){
                    chordRootNote = chord[i];
                    chord[i].color = darkgreen; //color root note in green
                }else if((chord[i].pitch%12) == ((rootNote+intervals[root_pos][0])%12)){
                    chord[i].color = darkyellow; //color third note in yellow
                }else if(intervals[root_pos].length>=3 && (chord[i].pitch%12) == ((rootNote+intervals[root_pos][2])%12)){
                    chord[i].color = darkred; //color 7th note in red
                }else{
                    chord[i].color = black; //reset other note color
                }
            }
        
            // ----- find root note
            /*var chordRootNote;
            for(var i=0; i<chord.length; i++){
                if(chord[i].pitch%12 == rootNote)
                    chordRootNote = chord[i];
            }*/
            
            // ----- find chord name:
            var notename="";
            if(chordRootNote.tpc != 'undefined' && chordRootNote.tpc<=33){
                if(chordRootNote.tpc==-1) 
                    notename=tpc_str[34];
                else
                    notename=tpc_str[chordRootNote.tpc];
            }
            chordName = notename + chords_str[idx_chtype];
        }

        // ----- find inversion
        inv=-1;
        if (chordName !== ''){ // && inversion !== null) {
            var bass_pitch=(chord[0].pitch%12);
            //console.log('bass_pitch: ' + bass_pitch);
            if(bass_pitch == rootNote){ //Is chord in root position ?
                inv=0;
            }else{
                for(var inv=1; inv<intervals[root_pos].length+1; inv++){
                   if(bass_pitch == ((rootNote+intervals[root_pos][inv-1])%12)) break;
                   //console.log('note n: ' + ((chord[root_pos].pitch+intervals[root_pos][inv-1])%12));
                }
            }
            console.log('\t inv: ' + inv);
            chordName += inversions[inv];
        }

        return chordName;
    }
    
    function getSegmentHarmony(segment) {
        //if (segment.segmentType != Segment.ChordRest) 
        //    return null;
        var aCount = 0;
        var annotation = segment.annotations[aCount];
        while (annotation) {
            if (annotation.type == Element.HARMONY)
                return annotation;
            annotation = segment.annotations[++aCount];     
        }
        return null;
    } 
    

    onRun: {
        //console.log('hello world');
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
        console.log('startStaff: ' + startStaff);
        console.log('endStaff: ' + endStaff);
        console.log('curScore.nstaves: ' + curScore.nstaves);
        console.log('endTick: ' + endTick);
        console.log('cursor.tick: ' + cursor.tick);
        console.log('curScore.lastSegment.tick: ' + curScore.lastSegment.tick);

        cursor.rewind(1); // beginning of selection
        cursor.voice = 0;
        cursor.staffIdx = startStaff; //staff;

        if (fullScore) { // no selection
            cursor.rewind(0); // beginning of score
        }

        var segment;
        while ((segment=cursor.segment) && (fullScore || cursor.tick < endTick)) { //loop through the selection
            
            // FIRST we get all notes on current position of the cursor, for all voices and all staves.
            var full_chord = [];
            var idx_note=0;
            for (var staff = endStaff; staff >= startStaff; staff--) {
                for (var voice = 3; voice >=0; voice--) {
                    cursor.staffIdx = staff;
                    cursor.voice = voice;
                    if (cursor.element && cursor.element.type == Element.CHORD) {
                        var notes = cursor.element.notes;
                        for (var i = 0; i < notes.length; i++) {
                              full_chord[idx_note]=notes[i];
                              idx_note++;
                        }
                    }
                }
            }

            if(idx_note!=0){ //More than 0 notes found!
                console.log('------');
                console.log('nb of notes found: ' + idx_note);
                var chordName = getChordName(full_chord);

                console.log('\tchordName: ' + chordName);

                if (chordName !== '') { //chord has been identified
                    var harmony = getSegmentHarmony(segment);
                    if (harmony && harmony.text) { //if chord symbol exists, replace it
                        //console.log("got harmony " + staffText + " with root: " + harmony.rootTpc + " bass: " + harmony.baseTpc);
                        harmony.text = chordName;
                    }else{ //chord symbol does not exist, create it
                        harmony = newElement(Element.HARMONY);
                        harmony.text = chordName;
                        //console.log("text type:  " + staffText.type);
                        cursor.add(harmony);

                    }
                    /*staffText = newElement(Element.STAFF_TEXT);
                    staffText.text = chordName;
                    staffText.pos.x = 0;
                    cursor.add(staffText);*/
                }
            }
            
            cursor.next();
        } // end while segment
        Qt.quit();
    } // end onRun
}