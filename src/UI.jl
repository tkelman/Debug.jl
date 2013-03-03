
#   Debug.UI:
# =============
# Interactive debug trap

module Session
using Debug
import Flow.DBState

const st   = DBState()
const bp   = st.breakpoints
const nobp = st.ignore_bp
const pre  = st.grafts

end # module


module UI
using Debug.Meta, AST, Eval, Flow
import Session
export trap

const helptext = 
E"Commands:
--------
h: display this help text
s: step into
n: step over any enclosed scope
o: step out from the current scope
c: continue to next breakpoint
q: quit debug session (calls error(\"interrupted\"))
To e.g. evaluate the variable named `n`, enter it as ` n` (with a space).

Debug variables:
---------------
$n:    current node
$s:    current scope
$bp:   Set{Node} of enabled breakpoints
$nobp: Set{Node} of disabled @bp breakpoints
$pre:  Dict{Node} of grafts

Example usage:
-------------
$(add!(bp, n))       # set breakpoint at the current node
$(delete!(bp, n))    # unset breakpoint at the current node
$(add!(nobp, n))     # ignore @bp breakpoint at the current node
$(pre[n] = :(x = 0)) # execute x=0 just before the current node, at each visit"


instrument(ex) = Flow.instrument(trap, ex)

function trap(node, scope::Scope)
    state = Session.st
    if Flow.pretrap(state, node, scope)
        #println("\nat ", node.loc.file, ":", node.loc.line, "\n")
        ndfile = string(node.loc.file)
        ndline = node.loc.line
        print_context(ndfile, ndline, 1)
        print("debug:$(ndline)> "); #flush(STDOUT)
        while true
            cmd = readline(STDIN)[1:end-1]
            if cmd == "s";     break
            elseif cmd == "n"; stepover!(state); break
            elseif cmd == "o"; stepout!(state, node, scope);  break
            elseif cmd == "c"; continue!(state); break
            elseif cmd == "q"; continue!(state); error("interrupted")
            elseif cmd == "l"; print_context(ndfile, ndline, 5)
            elseif ismatch(r"l ([0-9])", cmd)
                # Inefficient to match twice, but hack for now
                # This doesn't work right now b/c I couldn't convert the
                # captured digit to an int...
                mm = match(r"l ([0-9])",cmd)
                print_context(ndfile, ndline, parse_int(mm.captures[1]))
            elseif cmd == "h"; println(helptext)
            else
                try
                    ex0 = parse(cmd)
                    Session.eval(:( (n,s)=$(quot((node,scope))) ))
                    ex = interpolate(ex0)
                    r = debug_eval(scope, ex)
                    if !is(r, nothing); show(r); println(); end
                catch e
                    println(e)
                end
            end
            print("debug:$(ndline)> "); #flush(STDOUT)
        end
    end
    Flow.posttrap(state, node, scope)
end

interpolate(ex) = ex  # including QuoteNode
function interpolate(ex::Ex)
    if is_expr(ex, :$, 1)
        quot(Session.eval(argof(ex, 1)))
    elseif headof(ex) === :quote
        ex
    else
        expr(headof(ex), {interpolate(arg) for arg in ex.args})
    end
end

function print_context(path::String, line::Int, nsurr::Int)
    println("\nat ", path, ":", line, "\n")  # Double newlines intentional
    try
        src = readlines(open(string(path)))
        # This is cooler, but probably slower
        #src = open(string(path)) do f
        #    readlines(f)
        #end
        startl = max(1, line-nsurr)
        endl = min(length(src), line+nsurr)
        #println("\nstartl: $startl, endl: $endl")
        for li in startl:endl
            if li == line
                print("$(li)  -->  $(src[li])")
            else
                print("$(li)       $(src[li])")
            end
        end
        print("\n")
    catch err
        # Don't do anything for now
    end
end


end # module
