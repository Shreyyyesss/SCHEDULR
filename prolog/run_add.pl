
:- initialization(run_main).

run_main :-
  consult('C:/Users/lenovo/Desktop/smart-scheduler/prolog/scheduler.pl'),
  ( file_exists('C:/Users/lenovo/Desktop/smart-scheduler/prolog/temp_facts.pl') ->
      consult('C:/Users/lenovo/Desktop/smart-scheduler/prolog/temp_facts.pl')
  ;   true
  ),
  assertz(availability('gg', 12, 13)),
  tell('C:/Users/lenovo/Desktop/smart-scheduler/prolog/temp_facts.pl'),
  listing(availability),
  told,
  writeln('✅ Added gg 12-13'),
  halt.
