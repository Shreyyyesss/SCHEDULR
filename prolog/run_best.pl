
:- initialization(run_main).

run_main :-
  consult('C:/Users/lenovo/Desktop/smart-scheduler/prolog/scheduler.pl'),
  ( file_exists('C:/Users/lenovo/Desktop/smart-scheduler/prolog/temp_facts.pl') ->
      consult('C:/Users/lenovo/Desktop/smart-scheduler/prolog/temp_facts.pl')
  ;   writeln('⚠️ No facts file found, skipping consult.')
  ),
  ( best_slots(9, 18, 0.5, 0.5, BestStart, BestCount, BestPeople) ->
      write('BestStart='), write(BestStart), nl,
      write('Count='), write(BestCount), nl,
      write('People='), write(BestPeople), nl
  ;   writeln('No valid slots found')
  ),
  halt.
