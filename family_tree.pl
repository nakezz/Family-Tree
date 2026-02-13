% -------- ATA LINE --------
father(naiman, karakerei).
father(karakerei, baitory).
father(baitory, airam).
father(airam, jankuly).
father(jankuly, kojambet).
father(kojambet, ait).
father(ait, jarboldy).
father(jarboldy, koshkar).
father(koshkar, syrlybai).
father(syrlybai, satibaldy).
father(satibaldy, esengeldi).
father(esengeldi, kusemis).
father(kusemis, bainazar).
father(bainazar, konisbai).
father(konisbai, bospai).
father(bospai, ualikhan).
father(ualikhan, gombojav).
father(gombojav, amanbek).
father(amanbek, nurislam).

% -------- maya'S CHILDREN --------
mother(maya, janerke).
mother(maya, serikjan).


% -------- begjan'S CHILDREN --------
father(begjan, janerke).
father(begjan, serikjan).

% -------- galya'S CHILDREN --------
mother(galya, bazaraly).
mother(galya, aidana).
mother(galya, aimerei).
mother(galya, meirim).

% -------- hunai'S CHILDREN --------
father(hunai, bazaraly).
father(hunai, aidana).
father(hunai, aimerei).
father(hunai, meirim).

% -------- amanbek'S CHILDREN --------
father(amanbek, nurislam).
father(amanbek, elaman).
father(amanbek, bagjan).

% -------- gulsin'S CHILDREN --------
mother(gulsin, nurislam).
mother(gulsin, elaman).
mother(gulsin, bagjan).


% -------- gombojav'S CHILDREN --------
father(gombojav, amanbek).
father(gombojav, janarbek).
father(gombojav, askerbek).
father(gombojav, galya).
father(gombojav, maya).
father(gombojav, zoya).

% -------- aziman'S CHILDREN --------
mother(aziman, amanbek).
mother(aziman, janarbek).
mother(aziman, askerbek).
mother(aziman, galya).
mother(aziman, maya).
mother(aziman, zoya).

% -------- askerbek'S CHILDREN --------
father(askerbek, tanya).
father(askerbek, medine).

% -------- umirgul'S CHILDREN --------
mother(umirgul, tanya).
mother(umirgul, medine).


% -------- janarbek'S CHILDREN --------
father(janarbek, sultan).
father(janarbek, erasil).
father(janarbek, sarangoo).

% -------- ardagul'S CHILDREN --------
mother(ardagul, sultan).
mother(ardagul, erasil).
mother(ardagul, sarangoo).

male(naiman).
male(karakerei).
male(baitory).
male(airam).
male(jankuly).
male(kojambet).
male(ait).
male(jarboldy).
male(koshkar).
male(syrlybai).
male(satibaldy).
male(esengeldi).
male(kusemis).
male(bainazar).
male(konisbai).
male(bospai).
male(ualikhan).
male(gombojav).
male(amanbek).
male(janarbek).
male(askerbek).
male(nurislam).
male(elaman).
male(sultan).
male(erasil).
male(serikjan).
male(bazaraly).
male(begjan).
male(hunai).

female(galya).
female(zoya).
female(maya).
female(aimerei).
female(aidana).
female(meirim).
female(medine).
female(tanya).
female(bagjan).
female(sarangoo).
female(janerke).
female(gulsin).
female(aziman).
female(umirgul).
female(ardagul).


sibling(X, Y) :-
	mother(M, X),
	mother(M, Y),
    father(F, X),
    father(F, Y),
    X \= Y.


uncle(Uncle, Person) :-
    parent(P, Person),
    shares_parent(Uncle, P),
    male(Uncle).

aunt(Aunt, Person) :-
    parent(P, Person),
    shares_parent(Aunt, P),
    female(Aunt).

lineage(Person, []) :-
    \+ father(_, Person).

lineage(Person, [Father | Rest]) :-
    father(Father, Person),
    lineage(Father, Rest).

% -------- PARENT (generic) --------
parent(P, Child) :- father(P, Child).
parent(P, Child) :- mother(P, Child).

% -------- SHARES PARENT (broader sibling check) --------
% Two people are siblings if they share at least one parent
shares_parent(X, Y) :-
    parent(P, X),
    parent(P, Y),
    X \= Y.

% -------- SIBLINGS LIST --------
% Collects all siblings of a person into a list (no duplicates)
siblings_of(Person, Siblings) :-
    setof(S, shares_parent(Person, S), Siblings), !.
siblings_of(_, []).  % if no siblings found, return empty list

% -------- SIBLING COUNT --------
% Returns how many siblings a person has
sibling_count(Person, Count) :-
    siblings_of(Person, Siblings),
    length(Siblings, Count).

% -------- SIBLINGS INFO (pretty print) --------
% Prints a summary: who the siblings are and how many
siblings_info(Person) :-
    siblings_of(Person, Siblings),
    sibling_count(Person, Count),
    (   Count > 0
    ->  format("~w has ~w sibling(s):~n", [Person, Count]),
        print_siblings(Siblings)
    ;   format("~w has no siblings.~n", [Person])
    ).

print_siblings([]).
print_siblings([H|T]) :-
    format("  - ~w~n", [H]),
    print_siblings(T).

% -------- GRANDFATHER --------
grandfather(GF, Person) :-
    father(F, Person),
    father(GF, F).
grandfather(GF, Person) :-
    mother(M, Person),
    father(GF, M).

% -------- GRANDMOTHER --------
grandmother(GM, Person) :-
    father(F, Person),
    mother(GM, F).
grandmother(GM, Person) :-
    mother(M, Person),
    mother(GM, M).

% -------- CHILDREN --------
children_of(Person, Children) :-
    setof(C, parent(Person, C), Children), !.
children_of(_, []).

% -------- PRINT LIST HELPER --------
print_list([]).
print_list([H|T]) :-
    format("  - ~w~n", [H]),
    print_list(T).

% ========================================
%         PERSON INFO (full profile)
% ========================================
person_info(Person) :-
    format("~n========== INFO ABOUT: ~w ==========~n~n", [Person]),

    % --- Gender ---
    (   male(Person)
    ->  format("Gender: Male~n")
    ;   (   female(Person)
        ->  format("Gender: Female~n")
        ;   format("Gender: Unknown~n")
        )
    ),
    nl,

    % --- Father ---
    (   father(F, Person)
    ->  format("Father: ~w~n", [F])
    ;   format("Father: Unknown~n")
    ),

    % --- Mother ---
    (   mother(M, Person)
    ->  format("Mother: ~w~n", [M])
    ;   format("Mother: Unknown~n")
    ),
    nl,

    % --- Grandfather(s) ---
    (   setof(GF, grandfather(GF, Person), GFs)
    ->  format("Grandfather(s):~n"), print_list(GFs)
    ;   format("Grandfather(s): Unknown~n")
    ),

    % --- Grandmother(s) ---
    (   setof(GM, grandmother(GM, Person), GMs)
    ->  format("Grandmother(s):~n"), print_list(GMs)
    ;   format("Grandmother(s): Unknown~n")
    ),
    nl,

    % --- Siblings ---
    siblings_of(Person, Siblings),
    length(Siblings, SibCount),
    (   SibCount > 0
    ->  format("Siblings (~w):~n", [SibCount]), print_list(Siblings)
    ;   format("Siblings: None~n")
    ),
    nl,

    % --- Uncles ---
    (   setof(U, uncle(U, Person), Uncles)
    ->  format("Uncle(s):~n"), print_list(Uncles)
    ;   format("Uncle(s): None~n")
    ),

    % --- Aunts ---
    (   setof(A, aunt(A, Person), Aunts)
    ->  format("Aunt(s):~n"), print_list(Aunts)
    ;   format("Aunt(s): None~n")
    ),
    nl,

    % --- Children ---
    children_of(Person, Kids),
    length(Kids, KidCount),
    (   KidCount > 0
    ->  format("Children (~w):~n", [KidCount]), print_list(Kids)
    ;   format("Children: None~n")
    ),
    nl,

    % --- Lineage (paternal line) ---
    lineage(Person, Line),
    (   Line \= []
    ->  format("Paternal Lineage:~n"),
        print_lineage(Line)
    ;   format("Paternal Lineage: Unknown~n")
    ),

    format("~n====================================~n~n").

% -------- PRINT LINEAGE HELPER --------
print_lineage([]).
print_lineage([H|T]) :-
    format("  -> ~w~n", [H]),
    print_lineage(T).
