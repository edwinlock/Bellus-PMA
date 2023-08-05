function random_market(n)
    buyer_prices = 0.0:0.01:1.0
    buyer_weights = 1000:500:5000
    numbuyers = 100 
    buyerdata = BellusAuction.generate_buyerdata(buyer_prices, buyer_weights, n, numbuyers)
    supplyvals = 10000:1000:50000
    reserve_prices = 0.0:0.01:1.0
    reserve_pcts = 0.0:0.1:1.0
    supplierdata = BellusAuction.generate_supplierdata(supplyvals, reserve_prices, reserve_pcts, n)
    market = data2auction(buyerdata, supplierdata)
end

@testset "Randomly generated markets with 2 suppliers" begin
    for _ in 1:1000
        @test isequilibrium(exhaustivesearch(random_market(2), :gains)...)
    end
end

@testset "Randomly generated markets with 5 suppliers" begin
    for _ in 1:1000
        @test isequilibrium(exhaustivesearch(random_market(5), :gains)...)
    end
end