
:- initialization(run_main).

run_main :-
  consult('C:/Users/lenovo/Desktop/smart-scheduler/prolog/scheduler.pl'),
  ( file_exists('C:/Users/lenovo/Desktop/smart-scheduler/prolog/temp_facts.pl') ->
      consult('C:/Users/lenovo/Desktop/smart-scheduler/prolog/temp_facts.pl')
  ;   writeln('⚠️ No facts file found, skipping consult.')
  ),
  retractall(availability(_, _, _)),
  tell('C:/Users/lenovo/Desktop/smart-scheduler/prolog/temp_facts.pl'),
  listing(availability),
  told,
  writeln('✅ All availabilities cleared!'),
  halt.
