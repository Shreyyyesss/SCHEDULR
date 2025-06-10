% ------------------------------------------------------------
% File: scheduler.pl
% Purpose: Core logic for Smart Scheduler (Node + Prolog)
% ------------------------------------------------------------

% ✅ Ensure availability/3 is always dynamic and clean
:- abolish(availability/3).
:- dynamic(availability/3).

% ---------- UTILITIES ----------

% Helper to write a line with newline
writeln(X) :- write(X), nl.

% Convert HH:MM (list of character codes) to decimal hours
hhmm_codes_to_decimal(Codes, Decimal) :-
    Codes = [H1,H2,58,M1,M2|_], % Expect "HH:MM"
    H is (H1-48)*10 + (H2-48),
    M is (M1-48)*10 + (M2-48),
    Decimal is H + M/60.

% Convert decimal hours to HH:MM atom (GNU compatible)
decimal_to_time(Decimal, TimeAtom) :-
    Hour is floor(Decimal),
    Minute is round((Decimal - Hour) * 60),
    number_codes(Hour, HCodes),
    number_codes(Minute, MCodes0),
    (Minute < 10 ->
        MCodes = [48|MCodes0]  % prepend '0'
    ;   MCodes = MCodes0),
    append(HCodes, [58|MCodes], AllCodes),
    atom_codes(TimeAtom, AllCodes).

% Read a line as list of character codes (without dot or quotes)
read_line_codes_list(Codes) :-
    get_code(C),
    read_line_codes_list(C, Codes).

read_line_codes_list(10, []) :- !.   % newline
read_line_codes_list(-1, []) :- !.   % EOF
read_line_codes_list(C, [C|T]) :-
    get_code(N),
    read_line_codes_list(N, T).

% Trim spaces from both sides
trim_codes(Codes, Trimmed) :-
    drop_leading(Codes, L1),
    reverse(L1, R1),
    drop_leading(R1, R2),
    reverse(R2, Trimmed).

drop_leading([C|T], R) :- (C =< 32 -> drop_leading(T, R); R = [C|T]).
drop_leading([], []).

% Convert list of codes to atom
codes_to_atom(Codes, Atom) :- atom_codes(Atom, Codes).

% Read a decimal number from input
read_decimal(Decimal) :-
    read_line_codes_list(Codes0),
    trim_codes(Codes0, Codes),
    codes_to_decimal(Codes, Decimal).

codes_to_decimal(Codes, Decimal) :-
    codes_to_decimal(Codes, 0, 0, false, Decimal).

codes_to_decimal([], IntAcc, FracAcc, false, Decimal) :- Decimal is IntAcc.
codes_to_decimal([], IntAcc, FracAcc, true, Decimal) :-
    frac_length(FracAcc, L),
    Decimal is IntAcc + FracAcc / (10^L).
codes_to_decimal([46|T], IntAcc, _FAcc, false, D) :-  % dot
    codes_to_decimal(T, IntAcc, 0, true, D).
codes_to_decimal([C|T], IntAcc, FAcc, false, D) :-
    C >= 48, C =< 57,
    Digit is C - 48,
    NewInt is IntAcc*10 + Digit,
    codes_to_decimal(T, NewInt, FAcc, false, D).
codes_to_decimal([C|T], IntAcc, FAcc, true, D) :-
    C >= 48, C =< 57,
    Digit is C - 48,
    NewFrac is FAcc*10 + Digit,
    codes_to_decimal(T, IntAcc, NewFrac, true, D).

frac_length(0, 1) :- !.
frac_length(N, L) :- frac_length(N, 0, L).
frac_length(0, L, L) :- !.
frac_length(N, Acc, L) :-
    N1 is N // 10,
    Acc1 is Acc + 1,
    frac_length(N1, Acc1, L).

% ---------- CORE LOGIC ----------

% ✅ A person is free for a meeting if their availability covers that duration
free_for(Person, Start, Duration) :-
    End is Start + Duration,
    availability(Person, AStart, AEnd),
    AStart =< Start,
    End =< AEnd.

% ✅ Count attendees who can attend a slot
count_attendees(Start, Duration, Count, Attendees) :-
    findall(Person, (availability(Person, _, _), free_for(Person, Start, Duration)), P),
    sort(P, Attendees),
    length(Attendees, Count).

% ✅ Generate times between start & end with step
time_between(Start, End, _Step, Start) :- Start =< End.
time_between(Start, End, Step, T) :-
    Start < End,
    Next is Start + Step,
    time_between(Next, End, Step, T).

% ✅ Find best meeting slots
best_slots(WindowStart, WindowEnd, Duration, Step, BestStart, BestCount, BestPeople) :-
    findall([Count, Time, People],
        (time_between(WindowStart, WindowEnd, Step, Time),
         count_attendees(Time, Duration, Count, People),
         Count > 0),
        Results),
    sort(Results, Sorted),
    reverse(Sorted, [[BestCount, BestStart, BestPeople]|_]).

% ---------- INTERACTIVE CONSOLE (optional for manual testing) ----------

schedule_meeting :-
    retractall(availability(_,_,_)),
    writeln('-------------------------------------------'),
    writeln('         EVENT SCHEDULER (Interactive)'),
    writeln('-------------------------------------------'),
    writeln('Enter people''s availability below.'),
    writeln('Use HH:MM format, e.g., 09:30'),
    writeln('Type done when finished.'),
    collect_availability,
    writeln('-------------------------------------------'),
    writeln('All entries saved!'),
    writeln('Now enter meeting preferences.'),
    write('Meeting duration (in hours, e.g., 0.5 = 30 min): '),
    read_decimal(Duration),
    write('Start of window (HH:MM): '),
    read_line_codes_list(WinStart0),
    trim_codes(WinStart0, WinStart),
    hhmm_codes_to_decimal(WinStart, WindowStart),
    write('End of window (HH:MM): '),
    read_line_codes_list(WinEnd0),
    trim_codes(WinEnd0, WinEnd),
    hhmm_codes_to_decimal(WinEnd, WindowEnd),
    write('How often to check slots? (in minutes, e.g., 30): '),
    read_decimal(StepMinutes),
    Step is StepMinutes / 60,
    nl,
    (best_slots(WindowStart, WindowEnd, Duration, Step, BestStart, BestCount, BestPeople)
     -> decimal_to_time(BestStart, BestTime),
        write('Best meeting time: '), write(BestTime),
        write(' hrs ('), write(BestCount), write(' people): '), write(BestPeople), nl, nl,
        show_best_slots(WindowStart, WindowEnd, Duration, Step)
     ; writeln('No matching slots found!')
    ).

collect_availability :-
    write('Enter name (or done): '),
    read_line_codes_list(Name0),
    trim_codes(Name0, Name),
    codes_to_atom(Name, NameAtom),
    (NameAtom = done ->
        true
    ;   write('Start time (HH:MM): '),
        read_line_codes_list(SCodes0),
        trim_codes(SCodes0, SCodes),
        write('End time (HH:MM): '),
        read_line_codes_list(ECodes0),
        trim_codes(ECodes0, ECodes),
        hhmm_codes_to_decimal(SCodes, Start),
        hhmm_codes_to_decimal(ECodes, End),
        assertz(availability(NameAtom, Start, End)),
        writeln('Added!'),
        collect_availability
    ).

show_best_slots(WindowStart, WindowEnd, Duration, Step) :-
    findall([Count, Time, People],
        (time_between(WindowStart, WindowEnd, Step, Time),
         count_attendees(Time, Duration, Count, People),
         Count > 0),
        Results),
    sort(Results, Sorted),
    reverse(Sorted, Ordered),
    writeln('-------------------------------------------'),
    writeln('All possible meeting slots (sorted):'),
    writeln('-------------------------------------------'),
    show_slots_list(Ordered),
    writeln('-------------------------------------------'),
    writeln('End of schedule.').

show_slots_list([]).
show_slots_list([[Count, Time, People]|T]) :-
    decimal_to_time(Time, TimeAtom),
    write('Time: '), write(TimeAtom),
    write('  |  Attendees: '), write(People),
    write(' ('), write(Count), write(' people)'), nl,
    show_slots_list(T).
