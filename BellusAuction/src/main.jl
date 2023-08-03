using ArgParse

function parse_settings()
    s = ArgParseSettings()

    method_choices = ["exhaustive", "heuristic", "override-reserves"]
    objective_choices = ["gains", "numsuppliers"]

    @add_arg_table! s begin
        "--buyerfile", "-b"
            help = "The buyer CSV file"
            required = true
        "--supplierfile", "-s"
            help = "The buyer CSV file"
            required = true
        "--method", "-m"
            help = "Method used to solve the market. Choices are $(method_choices)."
            default = "exhaustive"
            range_tester = (x->x ∈ method_choices)
        "--objective", "-o"
            help = "The metric used by exhaustive search to find optimal solution. Choices are $(objective_choices). Ignored if another method is specified."
            default = "gains"
            range_tester = (x->x ∈ objective_choices)
        "--output-dir", "-d"
            help = "The directory in which to store output files. Default is the current directory (denoted '.'). Note that existing files are overwritten."
            default = "outcomes/"
        # "--verbose", "-v"
        #     help = "If provided, outputs information to the command line in addition to saving output to files."
        #     action = :store_true
    end
    return s
end

function main(args)
    s = parse_settings()
    parsed_args = parse_args(args, s)
    buyerfile = parsed_args["buyerfile"]
    supplierfile = parsed_args["supplierfile"]
    method = Symbol(parsed_args["method"])
    objective = Symbol(parsed_args["objective"])
    output_dir = abspath(parsed_args["output-dir"])
    # verbose = parsed_args["verbose"]

    market = files2auction(buyerfile, supplierfile)
    println("\n-------------------\nBellus-PMA software\n-------------------\n")
    println("Running auction with the following input files:")
    println("Buyer file: \"$(joinpath(output_dir, buyerfile))\" with $(numbuyers(market)) buyers and $(market.numbuyerbids) bids.")
    println("Supplier file: \"$(joinpath(output_dir, supplierfile))\" with $(numsuppliers(market)) sellers.\n")

    if method == :exhaustive
        println("Solving auction using \"exhaustive search\" method with \"$(objective)\" objective.\n")
        restricted_market, outcome = exhaustivesearch(market, objective)
    elseif method == :heuristic
        println("Using the \"heuristic\" method for finding prices and allocations of supply to buyers.\n")
        restricted_market, outcome = heuristic(market)

    elseif method == Symbol("override-reserves")
        println("Finding prices and allocations of supply to buyers while overriding supplier reserve quantities.\n")
        outcome = solve(market; override_reserves=true)
        restricted_market=market
    else
        error("Method is not implemented.")
    end
    
    print_outcomes(restricted_market, outcome)

    println("Outputs saved to files in directory \"$(output_dir)\".\n")
    save_outcomes(restricted_market, outcome, output_dir)

    println("Running verification checks.")
    is_envyfree(restricted_market, outcome) && println("Outcome is envy-free.")
    clears_market(restricted_market, outcome) && println("Outcome clears market.")
end