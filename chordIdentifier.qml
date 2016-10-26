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

    version: "1.2";
    description: "- Identify chords and put chord symbol on top.\n" +
                 "- Works with single or multiple voices, accross one or more staves.\n" +
                 "- Inversions are mentionned.\n" +
                 "- Notes are colored according to their function in the chord (NCTs stay in black)\n" +
                 "- Shows only chords used in classical music: triads (major, minor, diminished) and seventh chords (MM7, m7, Mm7, dim7)\n\n" +
                 "Comments, feedbacks, report bugs, ask for new features, contribute:\n" +
                 "https://musescore.org/en/project/chordidentifier";
    menuPath: "Plugins.Chords." + qsTr("Chord Identifier")
    
    property variant black : "#000000"
    property variant color7th : "#A00000"
    property variant color5th : "#803030"
    property variant color3rd : "#605050"
    property variant colorroot : "#005000"
    property variant red : "#ff0000"
    property variant green : "#00ff00"
    property variant blue : "#0000ff"
    
    // ---------- get note name from TPC (Tonal Pitch Class):
    function getNoteName(note_tpc){ 
        var notename = "";
        var tpc_str = ["Cbb","Gbb","Dbb","Abb","Ebb","Bbb",
            "Fb","Cb","Gb","Db","Ab","Eb","Bb","F","C","G","D","A","E","B","F#","C#","G#","D#","A#","E#","B#",
            "F##","C##","G##","D##","A##","E##","B##","Fbb"]; //tpc -1 is at number 34 (last item).
        if(note_tpc != 'undefined' && note_tpc<=33){
            if(note_tpc==-1) 
                notename=tpc_str[34];
            else
                notename=tpc_str[note_tpc];
        }
        return notename;
    }
    
    // ---------- remove duplicate notes from chord (notes with same pitch) --------
    function remove_dup(chord){
        var chord_notes=new Array();

        for(var i=0; i<chord.length; i++)
            chord_notes[i] = chord[i].pitch%12; // remove octaves

        chord_notes.sort(function(a, b) { return a - b; }); //sort notes

        var chord_uniq = chord_notes.filter(function(elem, index, self) {
            return index == self.indexOf(elem);
        }); //remove duplicates

        return chord_uniq;
    }
    
    // ---------- find intervals for all possible positions of the root note ---------- 
    function find_intervals(chord_uniq){
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
            console.log('\t intervals: ' + intervals[root_pos]);
        }

        return intervals;
    }
    
    function compare_arr(ref_arr, search_elt) { //returns an array of size ref_tab.length
        if (ref_arr == null || search_elt == null) return [];
        var cmp_arr=[], nb_found=0;
        for(var i=0; i<ref_arr.length; i++){
            if( search_elt.indexOf(ref_arr[i]) >=0 ){
                cmp_arr[i]=1;
                nb_found++;
            }else{
                cmp_arr[i]=0;
            }
        }
        return {
            cmp_arr: cmp_arr,
            nb_found: nb_found
        };
    }
        
    function getChordName(chord) {
        var INVERSION_NOTATION = 0; //set to 0: inversions are not shown
                                    //set to 1: inversions are noted with superscript 1, 2 or 3
                                    //set to 2: figured bass notation is used instead
                                
        var DISPLAY_BASS_NOTE = 1; //set to 1: bass note is specified after a / like that: C/E for first inversion C chord.
 
        //Standard notation for inversions:
        if(INVERSION_NOTATION===1){
            var inversions = ["", "\u00B9", "\u00B2"], // unicode for superscript "1", "2", "3" (e.g. to represent C Major first, or second inversion)
                inversions_7th = ["7", "\u00B9", "\u00B2", "\u00B3"]; //inversions for 7ths chords
        }else if(INVERSION_NOTATION===2){//Figured bass of inversions:
            var inversions = ["", "\u2076", "\u2076\u2084"],
                inversions_7th = ["\u2077", "\u2076\u2085", "\u2074\u2083", "\u2074\u2082"]; //inversions for 7ths chords
        }else{
            var inversions = ["", "", ""],
                inversions_7th = ["7", "7", "7", "7"]; //inversions for 7ths chords
        }
            
        var rootNote = null,
            inversion = null,
            partial_chord=0;
           
        // intervals (number of semitones from root note) for main chords types...          //TODO : revoir fonctionnement et identifier d'abord triad, puis seventh ?
        var chord_type = [ [4,7],  //M (0)
                            [3,7],  //m
                            [3,6],  //dim
                            [4,7,11],   //MM7 = Major Seventh
                            [3,7,10],   //m7 = Minor Seventh
                            [4,7,10],   //Mm7 = Dominant Seventh
                            [3,6,10]];   //dim7 = Half Diminished Seventh
        //... and associated notation:
        //var chord_str = ["", "m", "\u00B0", "MM7", "m7", "Mm7", "\u00B07"];
        var chord_str = ["", "m", "o", "MM", "m", "Mm", "o"];
        /*var chord_type_reduced = [ [4],  //M
                                    [3],  //m
                                    [4,11],   //MM7
                                    [3,10],   //m7
                                    [4,10]];  //Mm7
        var chord_str_reduced = ["", "m", "MM", "m", "Mm"];*/
        /*var major_scale_chord_type = [[0,3], [1,4], [1,4], [0,3], [0,5], [1,4], [2,6]]; //first index is for triads, second for seventh chords.
        var minor_scale_chord_type = [[0,4], [2,6], [0,3], [1,4], [0,5], [0,3], [2,6]];*/

        // ---------- SORT CHORD from bass to soprano --------
        chord.sort(function(a, b) { return (a.pitch) - (b.pitch); }); //bass note is now chord[0]
        
        //debug:
//        for(var i=0; i<chord.length; i++){
//            console.log('pitch note ' + i + ': ' + chord[i].pitch + ' -> ' + chord[i].pitch%12);
//        }   
        
        var chord_uniq = remove_dup(chord); //remove multiple occurence of notes in chord
        var intervals = find_intervals(chord_uniq);
        
        //debug:
        //for(var i=0; i<chord_uniq.length; i++) console.log('pitch note ' + i + ': ' + chord_uniq[i]);
        // console.log('compare: ' + compare_arr([0,1,2,3,4,5],[1,3,4,2])); //returns [0,1,1,1,1,0}
        
        
        // ---------- Compare intervals with chord types for identification ---------- 
        var idx_chtype=-1, idx_rootpos=-1, nb_found=0;
        var idx_chtype_arr=[], idx_rootpos_arr=[], cmp_result_arr=[];
        for(var idx_chtype_=0; idx_chtype_<chord_type.length; idx_chtype_++){ //chord types. 
            for(var idx_rootpos_=0; idx_rootpos_<intervals.length; idx_rootpos_++){ //loop through the intervals = possible root positions
                var cmp_result = compare_arr(chord_type[idx_chtype_], intervals[idx_rootpos_]);
                if(cmp_result.nb_found>0){ //found some intervals
                    if(cmp_result.nb_found == chord_type[idx_chtype_].length){ //full chord found!
                        if(cmp_result.nb_found>nb_found){ //keep chord with maximum number of similar interval
                            nb_found=cmp_result.nb_found;
                            idx_rootpos=idx_rootpos_;
                            idx_chtype=idx_chtype_;
                        }
                    }
                    idx_chtype_arr.push(idx_chtype_); //save partial results
                    idx_rootpos_arr.push(idx_rootpos_);
                    cmp_result_arr.push(cmp_result.cmp_arr);
                }
            }
        }
        
        if(idx_chtype<0 && idx_chtype_arr.length>0){ //no full chord found, but found partial chords
            console.log('other partial chords: '+ idx_chtype_arr);
            console.log('root_pos: '+ idx_rootpos_arr);
            console.log('cmp_result_arr: '+ cmp_result_arr);

            for(var i=0; i<cmp_result_arr.length; i++){
                if(cmp_result_arr[i][0]===1 && cmp_result_arr[i][2]===1){ //third and 7th ok (missing 5th)
                    idx_chtype=idx_chtype_arr[i];
                    idx_rootpos=idx_rootpos_arr[i];
                    console.log('3rd + 7th OK!');
                    break;
                }
            }
            if(idx_chtype<0){ //still no chord found. Check for third interval only (missing 5th and 7th)
                for(var i=0; i<cmp_result_arr.length; i++){
                    if(cmp_result_arr[i][0]===1){ //third ok 
                        idx_chtype=idx_chtype_arr[i];
                        idx_rootpos=idx_rootpos_arr[i];
                        console.log('3rd OK!');
                        break;
                    }
                }
            }
        }
            
        if(idx_chtype>=0){
            console.log('FOUND CHORD number '+ idx_chtype +'! root_pos: '+idx_rootpos);
            console.log('\t interval: ' + intervals[idx_rootpos]);
            rootNote=chord_uniq[idx_rootpos];
        }else{
            console.log('No chord found');
        }
            
        var regular_chord=[-1,-1,-1,-1]; //without NCTs
        var bass=null; 
        var seventhchord=0;
        var chordName='';
        if (rootNote !== null) { // ----- the chord was identified
            for(i=0; i<chord.length; i++){  // ---- color notes and find root note
                if((chord[i].pitch%12) === (rootNote%12)){  //color root note
                    regular_chord[0] = chord[i];
                    chord[i].color = colorroot; 
                    if(bass==null) bass=chord[i];
                }else if((chord[i].pitch%12) === ((rootNote+chord_type[idx_chtype][0])%12)){ //third note
                    regular_chord[1] = chord[i];
                    chord[i].color = color3rd; 
                    if(bass==null) bass=chord[i];
                }else if(chord_type[idx_chtype].length>=2 && (chord[i].pitch%12) === ((rootNote+chord_type[idx_chtype][1])%12)){ //5th
                    regular_chord[2] = chord[i];
                    chord[i].color = color5th;
                    if(bass==null) bass=chord[i];
                }else if(chord_type[idx_chtype].length>=3 && (chord[i].pitch%12) === ((rootNote+chord_type[idx_chtype][2])%12)){ //7th
                    regular_chord[3] = chord[i];
                    chord[i].color = color7th; 
                    if(bass==null) bass=chord[i];
                    seventhchord=1;
                }else{      //reset other note color 
                    chord[i].color = black; 
                }
            }
        
            // ----- find root note
            /*var chordRootNote;
            for(var i=0; i<chord.length; i++){
                if(chord[i].pitch%12 == rootNote)
                    chordRootNote = chord[i];
            }*/
            
            // ----- find chord name:
            var notename = getNoteName(regular_chord[0].tpc);
            chordName = notename + chord_str[idx_chtype];
            
        }

        // ----- find inversion
        inv=-1;
        if (chordName !== ''){ // && inversion !== null) {
            var bass_pitch=bass.pitch%12;
            //console.log('bass_pitch: ' + bass_pitch);
            if(bass_pitch == rootNote){ //Is chord in root position ?
                inv=0;
            }else{
                for(var inv=1; inv<chord_type[idx_chtype].length+1; inv++){
                   if(bass_pitch == ((rootNote+chord_type[idx_chtype][inv-1])%12)) break;
                   //console.log('note n: ' + ((chord[idx_rootpos].pitch+intervals[idx_rootpos][inv-1])%12));
                }
            }
            console.log('\t inv: ' + inv);
            if(seventhchord == 0){ //we have a triad:
                chordName += inversions[inv];
            }else{  //we have a 7th chord
                chordName += inversions_7th[inv];
            }
            
            if(DISPLAY_BASS_NOTE===1 && inv>0){
                chordName+="/"+getNoteName(bass.tpc);
            }
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
    
    function getAllCurrentNotes(cursor, startStaff, endStaff){
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
        return full_chord;
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
        if (fullScore) { // no selection
            cursor.rewind(0); // beginning of score
        }
        cursor.voice = 0;
        cursor.staffIdx = startStaff; //staff;
        
        var keySig = cursor.keySignature;
        var keysig_name_major = getNoteName(keySig+7+7);
        var keysig_name_minor = getNoteName(keySig+7+10);
        console.log('keysig: ' + keySig + ' -> '+keysig_name_major+' major or '+keysig_name_minor+' minor.');
        
        var segment;
        var chordName = '';
        while ((segment=cursor.segment) && (fullScore || cursor.tick < endTick)) { //loop through the selection
            // FIRST we get all notes on current position of the cursor, for all voices and all staves.
            var prev_full_chord = full_chord;
            var full_chord = getAllCurrentNotes(cursor, startStaff, endStaff);
            
            if(full_chord.length!=0){ //More than 0 notes found!
                console.log('------');
                console.log('nb of notes found: ' + full_chord.length);
                var prev_chordName = chordName;
                chordName = getChordName(full_chord);
                console.log('\tchordName: ' + chordName);

                if (chordName !== '') { //chord has been identified
                    var harmony = getSegmentHarmony(segment);
                    if (harmony) { //if chord symbol exists, replace it
                        //console.log("got harmony " + staffText + " with root: " + harmony.rootTpc + " bass: " + harmony.baseTpc);
                        harmony.text = chordName;
                    }else{ //chord symbol does not exist, create it
                        harmony = newElement(Element.HARMONY);
                        harmony.text = chordName;
                        //console.log("text type:  " + staffText.type);
                        cursor.add(harmony);
                    }
                    
                    if(prev_chordName == chordName){// && isEqual(prev_full_chord, full_chord)){ //same chord as previous one ... remove text symbol
                        harmony.text = '';
                    }
                    //console.log("xpos: "+harmony.pos.x+" ypos: "+harmony.pos.y);
                    /*staffText = newElement(Element.STAFF_TEXT);
                    staffText.text = chordName;
                    staffText.pos.x = 0;
                    cursor.add(staffText);*/
                }
            }
            
            cursor.next();
        } // end while segment
        
        if (fullScore) {
            var key_str='';
            if(chordName==keysig_name_major){   //if last chord of score is a I chord => we most probably found the key :-)
                key_str=keysig_name_major+' major';
            }else if(chordName==keysig_name_minor){
                key_str=keysig_name_minor+' minor';
            }else{
                console.log('Key not found :-(');
            }
            if(key_str!=''){
                console.log('FOUND KEY: '+key_str);
                /*var staffText = newElement(Element.STAFF_TEXT);
                staffText.text = key_str+':';
                staffText.pos.x = -13;
                staffText.pos.y = -1.5;
                cursor.rewind(0);
                cursor.add(staffText);*/
            }
        }
        Qt.quit();
    } // end onRun
}