:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_files)).
:- use_module(library(http/http_path)).
:- use_module(library(http/http_server_files)).

% Consult the family tree database
:- consult('family_tree.pl').

% Define the server port
server(Port) :-
    http_server(http_dispatch, [port(Port)]).

% Stop the server
stop_server(Port) :-
    http_stop_server(Port, []).

% Define handlers
:- http_handler(root(.), http_reply_file('family_tree.html', []), []).
:- http_handler(root(data), get_family_data, []).
:- http_handler(root(ask), handle_ask, []).
:- http_handler(root(.), serve_files, [prefix]).

serve_files(Request) :-
    http_reply_from_files('.', [], Request).

get_family_data(_Request) :-
    make,
    findall(Person, (male(Person); female(Person)), PeopleList),
    sort(PeopleList, UniquePeople),
    maplist(person_to_json, UniquePeople, Nodes),
    
    findall(Link, parent_child_link(Link), AllLinks),
    sort(AllLinks, Links),
    
    reply_json_dict(_{nodes: Nodes, links: Links}).

handle_ask(Request) :-
    catch(handle_ask_inner(Request), CatchAll,
        ( message_to_string(CatchAll, EMsg),
          format(string(ErrStr), "Server error: ~w", [EMsg]),
          reply_json_dict(_{error: ErrStr})
        )).

handle_ask_inner(Request) :-
    make,  % Reload any changed files (e.g. family_tree.pl)
    http_read_json_dict(Request, JSON),
    (   get_dict(query, JSON, QueryVal) ->
        % Convert string to atom (JSON gives strings, read_term_from_atom needs atom)
        atom_string(QueryAtom, QueryVal),
        (   catch(
                read_term_from_atom(QueryAtom, QueryTerm, [variable_names(Vars)]),
                ParseError, true)
        ->  (   var(ParseError)
            ->  % Successfully parsed - now execute
                (   Vars == []
                ->  % Ground query (no variables) - capture printed output
                    (   catch(
                            with_output_to(string(Output), call(QueryTerm)),
                            _, fail)
                    ->  (   Output == ""
                        ->  Reply = _{answer: "true."}
                        ;   Reply = _{answer: Output}
                        )
                    ;   Reply = _{answer: "false."}
                    )
                ;   % Query has variables - find all solutions
                    catch(
                        findall(Vars, call(QueryTerm), Solutions),
                        RunError,
                        ( message_to_string(RunError, RMsg),
                          format(string(REStr), "Runtime error: ~w", [RMsg]),
                          Solutions = [],
                          Reply = _{error: REStr}
                        )
                    ),
                    (   var(Reply) ->
                        (   Solutions == []
                        ->  Reply = _{answer: "false."}
                        ;   maplist(format_solution, Solutions, Strings),
                            atomic_list_concat(Strings, '\n', AnswerStr),
                            Reply = _{answer: AnswerStr}
                        )
                    ;   true
                    )
                )
            ;   message_to_string(ParseError, Msg),
                format(string(ErrMsg), "Syntax error: ~w", [Msg]),
                Reply = _{error: ErrMsg}
            )
        ;   Reply = _{error: "Failed to parse query."}
        )
    ;   Reply = _{error: "Missing 'query' field."}
    ),
    reply_json_dict(Reply).

format_solution(Bindings, String) :-
    maplist(format_binding, Bindings, BindingStrs),
    atomic_list_concat(BindingStrs, ', ', String).

format_binding(Name=Value, String) :-
    format(string(String), "~w = ~w", [Name, Value]).

person_to_json(Name, _{id: Name, gender: Gender}) :-
    (male(Name) -> Gender = male ; female(Name) -> Gender = female ; Gender = unknown).

parent_child_link(_{source: Father, target: Child, type: father}) :-
    father(Father, Child).
parent_child_link(_{source: Mother, target: Child, type: mother}) :-
    mother(Mother, Child).

% Start server immediately if run as script, or usage: ?- server(8080).
:- initialization(server(8080)).
