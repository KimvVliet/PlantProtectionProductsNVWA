__includes ["Setup_verified_EMA.nls" "Unit_tests_verification.nls"]
extensions [Table]

Breed [end_users end_user]
Breed [traders trader]
Breed [PPPs PPP] ; Plant Protection Product
Breed [orders order]
Breed [inspectors inspector]

globals [
  crop_list ; list of strings - the different crops an end-user can have
  disease_list ; list of strings - the different diseases the crop of an end-user can have
  sale_price_end_user_mother ; int - the sale price of a mother approval PPP to an end-user
  sale_price_end_user_bulk_illegal_EU ; int - the sale price of a bulk PPP to an end-user
  count_cured ; int - the number of disease cured in the model
  count_not_cured ; int - the number of crops that have died in the model
  illegal_EU_products_end_user ; int - the number of sales of illegal products in the EU to end-users
  NOP_products_end_user ; int - the number of sales of NOP products to end-users
  legal_products_end_user ; int - the number of sales of legal products to end-users
  max_traders_to_buy_from ; int - the maximum number of traders a trader can buy from
  profit_per_trader_to_trader_sale ; int - the profit a trader makes from a sale of a PPP to another trader
  inspection_list ; list of breeds - contains the types of agents that are inspected in this simulation
  company_observed_malpractice ; int - the number of times a trader is inspected and an offense is found
  company_observed_compliance ; int - the number of times a trader is inspected and no offenses are found
  online_order_set_end_users ; agentset - contains all orders that end-users can buy from the internet
  online_PPP_set_traders ; agentset - contains all orders that traders can buy from the internet
  PH_PPP_set_traders ; agentset - contains all orders of the permit holders that traders can buy from
  inspect_end_users? ; boolean - indicates whether end-users are to be inspected this model run
  inspect_end_user_only_traders? ; boolean - indicates whether end-user only traders are to be inspected this model run
  inspect_trader_to_trader_only_traders? ; boolean - indicates whether trader only traders are to be inspected this model run
]

end_users-own [
  crop_type_end_user ; string - the crop type of the end-user
  disease_crop_end_user ; string - the disease of the crop of the end-user
  buying_method ; string - the buying method of the end-user
  trust_in_via_traders ; int - the trust of the end-user in buying from traders
  trust_in_via_internet ; int - the trust of the end-user in buying from the internet
  propensity_to_violate ; int - the propensity to violate of the end-user
  my_trader ; agent - the local trader of the end-user
  months_with_disease ; int - the number of months a disease has been on the crops of the end-user
  inspected_this_tick? ; boolean - indicates whether the end-user has already been inspected this tick
  my_neighbors ; agentset - the agents that are in close proximity of the end-user whose opinion they consider
  faith_in_traders_lost_counter ; int - the number of times an end-user's crops died as a result of buying from its local trader
  my_stock ; agentset - the recent orders that an end-user has bought
]

traders-own [
  end_user_only? ; boolean - indicates whether the trader sells to end-users or traders only
  online_offer? ; boolean - indicates whether the trader offers its ware online to end-users
  requested_items_clients ; list - records agent requests for PPPs
  profit_this_year ; int - the profit a trader has made this year
  buying_method ; string - the buying method of the trader
  trust_in_via_traders ; int - the trust of the trader in buying from traders
  trust_in_via_PH ; int - the trust of the trader in buying from permit holders
  trust_in_via_internet ; int - the trust of the trader in buying from the internet
  propensity_to_violate ; int - the propensity to violate of the trader
  my_traders ; agentset - the traders this trader can buy from
  order_products? ; boolean - indicates whether the trader is out of stock on a product
  inspected_this_tick? ; boolean - indicates whether the the trader has already been inspected this tick
  column_number_trader ; int - indicates the row number of the trader for visualisation purposes
  my_stock ; agentset - the orders that are owned by the trader
]

PPPs-own [
  crop_type_PPP ; string - the crop type that the PPP is intended for
  disease_PPP ; string - the disease that the PPP can cure
  mother? ; boolean - indicates whether the PPP is a mother approval
  effectiveness ; string - the average effectiveness of the PPP
  sale_price_end_user ; int - the price at which the PPP is sold to the end-user
  legal_in_EU? ; boolean - indicates whether the PPP is legal in the EU
  original_product? ; boolean - indicates whether the PPP is an original product
  similarity_to_original_product ; int - the overall similarity of the PPP to the original product
]

orders-own [
  PPP_in_order ; agent - the PPP that is in the order
  number_of_PPPs ; int - the number of PPPs that is in the order
  owner ; agent - the owner of the order
  previous_owners ; agentset - the previous owners of the order
  online? ; boolean - indicates whether the order is to be sold online
  selling_method ; string - the method by which the order was sold to the current owner
  dead_counter ; int - counter that records the time until an order is supposed to die in the simulation
]

inspectors-own [
  assigned_to ; agent - the inspection target of the inspector
]

patches-own [
  crop_type_patch ; string - the type of crop that can be farmed on the crop
  square_for_agent ; breed - indicates what breed of agent can be placed on this patch (for visualisation purposes)
  type_of_buying_method ; string - indicates the type of buying method this patch represents (for visualisation purposes)
  column_number ; int - indicates the column that the patch is in (for visualisation purposes)
]

To setup
  clear-all
  reset-ticks

  ; set up the setup variables
  set max_traders_to_buy_from 3
  set sale_price_end_user_mother 100
  set sale_price_end_user_bulk_illegal_EU 60
  set profit_per_trader_to_trader_sale 5

  ; call the setup procedures
  set_seed
  change_int_to_boolean_EMA
  create_crop_list
  create_plots_of_land
  if progression_visualisation? [create_visualisation]
  create_agents
  create_authorisations
  set_up_initial_stock_traders
  create_online_offer
  create_inspection_list

end

To go

  ; every year, perform the yearly trader actions
  if ticks mod 12 = 1 and ticks > fixed_trust_period [ yearly_check_traders ]

  ; end-users get disease on their crops and set a buying strategy
  ask end_users [
    set buying_method 0
    plants_get_diseases
    end_users_set_strategy

    ; if an end-user changed its strategy, let it move to the corresponding row on the map
    if progression_visualisation? [
      ask end_users [
        if [type_of_buying_method] of patch-here != buying_method and buying_method != 0 [
          move-to one-of patches with [column_number = [column_number_trader] of [my_trader] of myself and square_for_agent = (word [breed] of myself) and type_of_buying_method = [buying_method] of myself and pcolor != black ]
        ]
      ]
    ]

    ; end-users buy a product
    if disease_crop_end_user != "none" [
      if buying_method = "trader" [ end_users_with_diseases_ask_traders ]
      if buying_method = "internet" [ end_users_with_diseases_search_internet ]
    ]
  ]

  ; traders restock
  ; first traders that do not serve end-users restock, so that they have sufficient stock to serve their trader clients
  ask traders with [end_user_only? = false and order_products?] [
    traders_set_stocking_strategy
    restock
  ]

  ; next traders that serve end-users restock
  ask traders with [end_user_only? and order_products?] [
    traders_set_stocking_strategy
    restock
  ]

  ; empty orders die after their expiry date
  ask orders [if number_of_PPPs <= 0 [
    set dead_counter dead_counter - 1
    if dead_counter <= 0 [ die ]]]

  ; inspections are carried out by inspectors
  ask inspectors [
    inspect_random
  ]

  ; reset the inspection variable after inspections
  ask end_users with [inspected_this_tick?] [ set inspected_this_tick? false]
  ask traders with [inspected_this_tick?] [ set inspected_this_tick? false]

  ; if end-users trust their trader very little, they start considering the internet as a means of acquiring PPPs.
  ; it takes five times of being very dissatisfied with their local trader to start considering the internet.
  let minimum_trust_in_via_traders 10
  ask end_users [
    if trust_in_via_traders < minimum_trust_in_via_traders and trust_in_via_internet = 0 [
      set faith_in_traders_lost_counter faith_in_traders_lost_counter + 1

      let times_faith_lost_to_use_internet 5
      if faith_in_traders_lost_counter > times_faith_lost_to_use_internet [
        let start_trust_in_via_internet 50
        set trust_in_via_internet start_trust_in_via_internet
      ]
    ]
  ]

  tick

end

To yearly_check_traders

  ; perform the yearly updating
  ; profit is checked and requested items of clients are updated
    ask traders [
      check_profit
      set profit_this_year 0
      update_request_data
    ]

end

To check_profit

  ; if the trader did not make sufficient profit this year, decrease the trust in their current buying method by 50%
  let %_reduction_trust_current_strategy_upon_bankruptcy -50
  if profit_this_year < minimum_profit  [
    adjust_trust %_reduction_trust_current_strategy_upon_bankruptcy
  ]

end

To adjust_trust [%_trust_increase]

  ; reduce or increase trust by the percentage provided

  ; only do this when the fixed_trust_period has been passed
  if ticks > fixed_trust_period [

    ; trust cannot go over 100 or to 0
    ; however, reaching 0 would forbid further multiplications (0.2 * 0 remains 0), therefore we set a minimum at 0.0001
    if buying_method = "trader" [ set trust_in_via_traders max list 0.0001 min list 100 (trust_in_via_traders + trust_in_via_traders * %_trust_increase / 100) ]
    if buying_method = "internet" [ set trust_in_via_internet max list 0.0001 min list 100 (trust_in_via_internet + trust_in_via_internet * %_trust_increase / 100) ]
    if buying_method = "permit_holder" [ set trust_in_via_PH max list 0.0001 min list 100 (trust_in_via_PH + trust_in_via_PH * %_trust_increase / 100) ]
  ]
end

To update_request_data

  ; Remove 1/3rd of all buyer data every year.

  if round ((ticks - fixed_trust_period) / 12 mod 3) = 0 [

    remove_request_data (list "year 0") (list "year 0")

  ]

  if round ((ticks - fixed_trust_period) / 12 mod 3) = 1 [

    remove_request_data (list "year 1") (list "year 1")
  ]

  if round ((ticks - fixed_trust_period) / 12 mod 3) = 2 [

    remove_request_data (list "year 2") (list "year 2")
  ]

end

To remove_request_data [last_year new_year]

  ; update the client request data memory
  ; after three years, start removing data from the year three years back
  let nr_of_requests_to_remove position last_year requested_items_clients + 1
  repeat nr_of_requests_to_remove [
    set requested_items_clients remove-item 0 requested_items_clients
  ]

  ; put a new year marker in the list
  set requested_items_clients lput new_year requested_items_clients

end

To plants_get_diseases

  ; end-users get diseases based on a user-defined random chance
  ; only end-users that do not currently have a disease on their crops can get a disease
  if random 100 < %_avg_chance_to_get_disease and disease_crop_end_user = "none" [
    set disease_crop_end_user one-of disease_list
  ]

end

To end_users_set_strategy

  ; end-users set their buying strategy based on their respective trust in the buying methods and the preferred buying method of their neighbors.
  ; end-users can buy from their trader or the internet

  ; calculate trust of my neighbors in buying methods
  let factor_neighbors_traders 1
  let factor_neighbors_internet 1

  if any? my_neighbors [

    let neighbors_choosing_traders count my_neighbors with [trust_in_via_traders >= trust_in_via_internet]
    let neighbors_choosing_internet count my_neighbors with [trust_in_via_internet > trust_in_via_traders]

    set factor_neighbors_traders (1 + neighbors_choosing_traders) / (count my_neighbors + 2)
    set factor_neighbors_internet (1 + neighbors_choosing_internet) / (count my_neighbors + 2)
  ]

  ; whilst the fixed_trust_period is in place, the buying method is always the trader
  ; this is done to ensure that traders get a chance to calibrate the products needed by their buyers
  ifelse ticks < fixed_trust_period [
    if disease_crop_end_user != "none" [set buying_method "trader"]
  ][
    if disease_crop_end_user != "none" [

      ifelse trust_in_via_traders * factor_neighbors_traders > trust_in_via_internet * factor_neighbors_internet [
        set buying_method "trader"
      ][
        set buying_method "internet"

        ; if the trust in traders equals the trust in the internet, end-users will most often choose to buy from their trader
        let chance_trader_if_equal 0.7
        if trust_in_via_traders = trust_in_via_internet and random-float 1 < 0.7 [ set buying_method "trader" ]
      ]
    ]
  ]


end

To end_users_with_diseases_ask_traders

  ; end_users that have set their strategy at "trader" will search through the products that are offered by their trader and pick a suitable PPP randomly

  ; add the request of the end-user to the requested products of the trader
  ask my_trader [
    set requested_items_clients lput (list [crop_type_end_user] of myself [disease_crop_end_user] of myself) requested_items_clients ]

  ; if the trader has a suitable PPP available for the end-user, he will offer it to them
  ; a suitable PPP is a PPP that is suitable for the disease and crop type of the end-user
  let suitable_offer [my_stock] of my_trader
  set suitable_offer suitable_offer with [[crop_type_PPP] of PPP_in_order = [crop_type_end_user] of myself and [disease_PPP] of PPP_in_order = [disease_crop_end_user] of myself and number_of_PPPs > 0]

  ; if the end-user always abides by the law, remove the potential products of the trader that are illegal in the EU.
  if propensity_to_violate < %_always_comply_end_users [
    set suitable_offer suitable_offer with [[legal_in_EU?] of PPP_in_order]
  ]

  ifelse any? suitable_offer [
    set suitable_offer one-of suitable_offer
    let NOP_discovered? discover_NOP suitable_offer
    if NOP_discovered? = false [
      ; trade the actual product
      trade_product suitable_offer

      ; the end-user will buy and use this product
      use_product suitable_offer

    ]

  ][

    ; if no product is available for the specific crop type of the end-user, the products that are not for the crop type yet are suitable for the disease of the end user
    ; become available
    let second_best_offer [my_stock] of my_trader
    set second_best_offer second_best_offer with [[crop_type_PPP] of PPP_in_order != [crop_type_end_user] of myself and [disease_PPP] of PPP_in_order = [disease_crop_end_user] of myself and number_of_PPPs > 0]

    ; if the end-user always abides by the law, remove the potential products of the trader that are illegal in the EU.
    if propensity_to_violate < %_always_comply_end_users [
      set second_best_offer second_best_offer with [[legal_in_EU?] of PPP_in_order]
    ]

    ;
    ifelse any? second_best_offer [
      set second_best_offer one-of second_best_offer
      let NOP_discovered? discover_NOP second_best_offer
      if NOP_discovered? = false [
        ; trade the actual product
        trade_product second_best_offer

        ; the end-user buys and uses the product
        use_product second_best_offer
      ]

      ; since the trader does not have a suitable product for the end-user, the trader will restock
      ask my_trader [
        set order_products? true
      ]
    ][

      ; if the trader of the end-user did not offer anything the trader will restock and the end-user will go into the "no cure" procedure
      ask my_trader [
        set order_products? true ]
      end_user_no_cure false
    ]
  ]


end

To use_product [order_offered]

  ; end-users buy and use the product

  let product [PPP_in_order] of order_offered
  let disease_cured? false

  ; if the product that was offered is not meant for the crop of the end-user
  ; then the effectiveness decreases by 10%
  let relative_effectiveness [effectiveness] of product
  let decrease_in_effectiveness_PPP_for_different_crop -20
  let knowingly_different_product_for_crop? false
  if [crop_type_PPP] of product != crop_type_end_user [
    set knowingly_different_product_for_crop? true
    set relative_effectiveness relative_effectiveness + relative_effectiveness * decrease_in_effectiveness_PPP_for_different_crop / 100
  ]

  ; determine if the product worked
  ifelse random 100 < relative_effectiveness [
    set disease_cured? true
    end_user_cure
  ][

    ; if it did not, enter the "no cure" procedure
    ; include whether the end-user knew that he was using a product that was originally designed for a different crop
    ; this will lead to a lesser reduction in trust in the buying method (see procedure end_user_no_cure)
    end_user_no_cure knowingly_different_product_for_crop?
  ]

end

To trader_makes_money [order_offered]

  ; let the owner of the sold PPP make money
  if [owner] of order_offered != "internet" [
    ask [owner] of order_offered [

      ; if the product is an original product ór the selling trader has bought the product for full price from another trader
      ; make half the sale_price_to_end_user as profit, minus 10% per trader who owned the product before me
      ifelse [original_product?] of [PPP_in_order] of order_offered or length [previous_owners] of order_offered > 0  [
        let sale_multiplier_original_product_trader_to_trader 0.5
        set profit_this_year profit_this_year + round (sale_multiplier_original_product_trader_to_trader * [sale_price_end_user] of [PPP_in_order] of order_offered - length [previous_owners] of order_offered * profit_per_trader_to_trader_sale)
      ][

        ; if the product is fake, the trader makes more money
        let sale_multiplier_NOP_product_trader_to_trader 0.9
        set profit_this_year profit_this_year + round (sale_multiplier_NOP_product_trader_to_trader * [sale_price_end_user] of [PPP_in_order] of order_offered - length [previous_owners] of order_offered * profit_per_trader_to_trader_sale)
      ]
    ]
  ]

end

To register_KPI

  ; register which products arrive at the end-user

  if legal_in_EU? = false [
    set illegal_EU_products_end_user illegal_EU_products_end_user + 1
  ]

  if original_product? = false [
    set NOP_products_end_user NOP_products_end_user + 1
  ]

  if legal_in_EU? and original_product? [
    set legal_products_end_user legal_products_end_user + 1
  ]

end

To end_user_cure

  ; set variables back to no disease status and update trust

  set count_cured count_cured + 1
  set disease_crop_end_user "none"
  set months_with_disease 0

  ; if it did, increase the trust of the end-user in the selling method
  let %_trust_increase_upon_cure 30
  change_trust_end_user %_trust_increase_upon_cure

end

To trade_product [order_offered]

  ; register the trade for the KPIs
  let product [PPP_in_order] of order_offered
  ask product [ register_KPI ]

  let customer self
  ask order_offered [

    ; if the end-user bought the product via the internet from another trader, ensure that the end-user's request is in the trader's request history
    if owner != [my_trader] of customer and owner != "online" [
      ask owner [set requested_items_clients lput (list [crop_type_PPP] of [PPP_in_order] of order_offered [disease_PPP] of [PPP_in_order] of order_offered) requested_items_clients]
    ]

    ; one PPP is sold - update the number of PPPs in the order
    set number_of_PPPs number_of_PPPs - 1

    ; the trader gets paid for the sale
    trader_makes_money order_offered

    ; if there are no more PPPs in the order, this means the order is completely sold

    if number_of_PPPs <= 0 [

      ; set the order up to die
      ; orders don't die immediately, because otherwise inspectors could never find orders that have just been sold
      set dead_counter 5

      ; if a trader sells a whole order without problems, their trust in the buying method increases
      if ticks > fixed_trust_period [
        let %_increase_trust_upon_full_sale 30
        if selling_method = "trader" [ ask owner [ set trust_in_via_traders min list 100  (trust_in_via_traders + trust_in_via_traders * %_increase_trust_upon_full_sale / 100) ]]
        if selling_method = "internet" [ ask owner [ set trust_in_via_internet min list 100 (trust_in_via_internet + trust_in_via_internet * %_increase_trust_upon_full_sale / 100)]]
        if selling_method = "permit_holder" [ ask owner [ set trust_in_via_PH min list 100 (trust_in_via_PH + trust_in_via_PH * %_increase_trust_upon_full_sale / 100)]]
      ]
    ]

    ; create one new, empty order for the end-user
    ; this is done so that inspectors can find the PPPs that were used by the end-users
    hatch 1 [
      set shape "PPP"
      set number_of_PPPs 0
      set previous_owners lput owner previous_owners
      set owner customer
      set selling_method [buying_method] of customer
      set dead_counter 5
      set online? false
      ask customer [set my_stock (turtle-set my_stock myself)]
      ; color the order according to the legal status of the product
      if progression_visualisation? [
        set_color_according_to_legal_status PPP_in_order
      ]
    ]
  ]

  ; color the agent according to what it has bought
  if progression_visualisation? [
    set_color_according_to_legal_status product
  ]

end

To end_user_no_cure [knowingly_second_best_option?]

  ; when the disease of the crop of the end-user is not cured, decrease their trust in their buying method

  ; first update KPI
  set count_not_cured count_not_cured + 1

  ; after three months with the same disease, an end-user's crops die
  ; this decreases their trust by a large amount (40%)
  ; for every month no cure, their trust is decreased by a little
  let max_disease_duration_months 3
  set months_with_disease months_with_disease + 1
  ifelse months_with_disease >= max_disease_duration_months [

    ; crops die: reset disease variables
    set disease_crop_end_user "none"
    set months_with_disease 0

    ; reduce trust by 40%
    let %_trust_reduction_upon_plant_death  -40

    ; if the end-user knew the PPP they got was their second-best option, reduce their trust by less.
    if knowingly_second_best_option? [ set %_trust_reduction_upon_plant_death  -10 ]

    change_trust_end_user %_trust_reduction_upon_plant_death

  ][

    ; if the disease is not cured within one month, decrease trust by 20%, unless the end-user knowingly got offered a second-best option
    let %_trust_reduction_upon_no_product_or_no_cure_traders_once  -20
    if knowingly_second_best_option? [ set %_trust_reduction_upon_no_product_or_no_cure_traders_once  -5 ]
    change_trust_end_user %_trust_reduction_upon_no_product_or_no_cure_traders_once
  ]

end

To change_trust_end_user [%_change_trust]

  ; change the trust of the end-user according to the trust modification provoked by the event that got the end-user in this procedure and the buying method of the end-user
  if ticks > fixed_trust_period [
    ifelse buying_method = "trader" [
      set trust_in_via_traders min list 100 (trust_in_via_traders + %_change_trust * trust_in_via_traders / 100)]
    [set trust_in_via_internet min list 100 (trust_in_via_internet + %_change_trust * trust_in_via_internet / 100)]
  ]

end


To traders_set_stocking_strategy

  ; traders set their buying strategy: via another trader, a permit holder or the internet

  if ticks > fixed_trust_period [

    let got_strategy? false

    ; if they trust the internet most and they do not always comply to the rules and the risk calculation falls towards using the internet: set the internet as strategy
    if trust_in_via_internet >= trust_in_via_traders and trust_in_via_internet >= trust_in_via_PH and propensity_to_violate > %_always_comply_traders [
      ; the risk calculation depends on the estimated chance of getting inspected and the fine-to-profit ratio
      let estimated_chance_to_get_inspected nr_of_inspectors / (nr_of_end_users + nr_of_traders)

      if estimated_chance_to_get_inspected * fine-to-profit_ratio < propensity_to_violate / 100 [
        set got_strategy? true
        set buying_method "internet"
      ]
    ]

    ; if a trader does not want to use the internet or does not trust it and they trust other traders most and they have other traders to trade with
    ; set other traders as a strategy
    ifelse got_strategy? = false and trust_in_via_traders >=  trust_in_via_PH and count turtle-set my_traders != 0 [
      set buying_method "trader"
    ][
      ; otherwise, set the permit holder as a strategy
      if got_strategy? = false [set buying_method "permit_holder"]
    ]
  ]

  ; if a trader changed its strategy, let it move to the corresponding row on the map
  if progression_visualisation? [
    if [type_of_buying_method] of patch-here != buying_method [
      move-to one-of patches with [column_number = [column_number_trader] of myself and square_for_agent = (word [breed] of myself) and type_of_buying_method = [buying_method] of myself and pcolor != black ]
    ]
    ;create visual links to the trader's trader network to show the trader is buying from traders
    ifelse buying_method = "trader" and my_traders != 0 [
      create-links-to turtle-set my_traders
      ask links [ set color black ]
    ][
      ; if the trader is not buying from other traders and it still has visual links, remove links
      ask my-out-links [die]
    ]
  ]

end

To restock
  ; traders ensure that they stock enough products to satisfy their customers

  ; first let a trader decide what it wants to stock.
  let stock_request decide_what_to_stock

  if buying_method = "internet"  [

    ;order illegal products from the internet
    order_product_PH_internet stock_request online_PPP_set_traders

  ]

  if buying_method = "permit_holder" [

    ;order items legally from a permit holder
    order_product_PH_internet stock_request PH_PPP_set_traders

  ]

  if buying_method = "trader" [
    ; order items from another trader
    order_product_traders stock_request
  ]

  set order_products? false
end

To-report decide_what_to_stock

  ; create a dictionary with [crop disease] as the key and the counted requests as the values
  let dict_crop_disease_count table:make

  ; loop over the requested items
  foreach requested_items_clients [ request ->

    let weight_of_count 1

    ; determine if the request was from a trader
    ; if it is from a trader, it can be more than 1 item, therefore take the weight of the number of items that are requested
    if length request = 3 [
      ; remove the extra info of the request and reset weight
      set weight_of_count item 2 request
      set weight_of_count ceiling (weight_of_count / max_traders_to_buy_from)
      set request remove-item 2 request
    ]

    ; add the request to the dictionary
    ; (carefully because there are only two options: the requested item is already in the dictionary and the count should be added to the previous count, or it is not and a new entry should be made)
    carefully [
      let current_count table:get dict_crop_disease_count request
      table:put dict_crop_disease_count request current_count + weight_of_count
    ]
    [ table:put dict_crop_disease_count request weight_of_count ]
  ]

  ; request data are stored for three years
  ; therefore, every traders should only buy one third of all requested products
  let relevant_years_client_request 3

  ; determine which products to stock based on the number of requests
  ; requests should be at least an average of 1 per year for the product to be stocked
  foreach table:keys dict_crop_disease_count [ dict_key ->

    let total_count table:get dict_crop_disease_count dict_key

    ifelse total_count >= relevant_years_client_request [

      ; the trader needs only one third of the total requested products plus some extra
      let nr_of_products_needed ceiling (total_count / relevant_years_client_request)

      ; sum the PPPs that we still have of this type of product
      let relevant_orders orders with [[crop_type_PPP] of PPP_in_order = item 0 dict_key and [disease_PPP] of PPP_in_order = item 1 dict_key and owner = myself]
      let nr_of_products_in_stock sum [number_of_PPPs] of relevant_orders

      ; compare the requested products vs. what still is in stock
      ifelse nr_of_products_in_stock < nr_of_products_needed [

        ; if there are insufficient products in stock, add the difference in requested vs. in stock to the to-buy dictionary
        table:put dict_crop_disease_count dict_key nr_of_products_needed - nr_of_products_in_stock
      ]

      ; if there is sufficient stock, remove the product from the to-buy dictionary
      [table:remove dict_crop_disease_count dict_key]][table:remove dict_crop_disease_count dict_key]
  ]

  report dict_crop_disease_count

end

To order_product_PH_internet [ stock_request_dict available_items ]

  ; trader buys available products from permit holder or the internet
  let me self

  ; for every product the trader wants to buy
  foreach table:keys stock_request_dict [ item_request ->

    ; retrieve the properties of the product
    let place_crop_in_list 0
    let place_disease_in_list 1

    ; choose an item to buy from the available items
    let product_to_buy one-of available_items with [crop_type_PPP = item place_crop_in_list item_request and disease_PPP = item place_disease_in_list item_request]

    ; if there is a product available
    ifelse product_to_buy != nobody [

      ; check if it is sent to the trader without problems
      let package_came_through? send_package product_to_buy

      ; if it is sent without problems
      ifelse package_came_through? [

        ; create a new order with the requested number of products
        hatch-orders 1 [
          set shape "PPP"
          set PPP_in_order product_to_buy
          set number_of_PPPs table:get stock_request_dict item_request
          set owner me
          set previous_owners []
          set selling_method [buying_method] of me
          set dead_counter "none"

          ; if the trader who buys the product sells its ware online, set the online? status of the order to true
          ifelse [online_offer?] of me [
            set online_order_set_end_users (turtle-set online_order_set_end_users self)
            set online? true
          ][
            set online? false
          ]

          ; color the order according to the legal status of the product
          if progression_visualisation? [
            set_color_according_to_legal_status PPP_in_order
            move-to owner
          ]
          ask owner [set my_stock (turtle-set my_stock myself)]
      ]] [

        ; if the package was caught and withheld, reduce the trust of the trader in the buying method
        let %_reduction_trust_strategy_upon_product_not_sent -20
        adjust_trust %_reduction_trust_strategy_upon_product_not_sent
      ]
    ]
    [
      ; if no product was available, reduce the trust of the trader in this buying method
      let %_reduction_trust_strategy_upon_no_product -10
      ask me [adjust_trust %_reduction_trust_strategy_upon_no_product ]]
  ]

end


To-report send_package [product_ordered]

  ; check whether a package from a seller outside the NL reaches the buyer

  ; if it is a legal product, the package always comes through
  let package_comes_through? true

  ; if the product is illegal or a NOP product, it might get inspected
  if [legal_in_EU?] of product_ordered = false or [original_product?] of product_ordered = false  [

    ; if the product gets inspected and it is illegal in the EU, it will get caught
    ; if the product is an NOP product, whether it gets caught depends on the similarity to the original product
    if random 100 < inspection_chance_NL_border [
      if [original_product?] of product_ordered or random 100 >= [similarity_to_original_product] of product_ordered [
        set package_comes_through? false
      ]
    ]
  ]

  report package_comes_through?

end

To order_product_traders [stock_request]

  ; order items from traders with whom I have buyer links

  let requested_products table:keys stock_request
  let new_owner self

  ; ask the traders from whom this trader buys products to add the product that I request to their requested products
  ; divide by the maximum number of traders that I buy from, otherwise requested products will be multiplied endlessly (from one trader to another)
  if end_user_only? [
    foreach requested_products [ requested_product ->
      ask my_traders [set requested_items_clients lput( list item 0 requested_product item 1 requested_product ceiling (table:get stock_request requested_product / max_traders_to_buy_from )) requested_items_clients]]
  ]

  ; sell the orders with the lowest number of PPPs first
  let suitable_orders turtle-set [my_stock] of my_traders
  set suitable_orders suitable_orders with [ number_of_PPPs > 0 ]

  ; check the stock of my traders for products that I can buy
  ask suitable_orders [
    let product list [crop_type_PPP] of PPP_in_order [disease_PPP] of PPP_in_order
    let legal? [legal_in_EU?] of PPP_in_order

    ; if any of the traders has a suitable item in stock
    if member? product requested_products [

      ; if this product is legal or I don't care if it's legal and I still need some of this product, buy it
      if (legal? = false and [propensity_to_violate] of myself > %_always_comply_traders) or legal? [

        let discovered_NOP? false

        ask owner [set discovered_NOP? discover_NOP myself]

        if discovered_NOP? = false [

          ; check if the seller has sufficient order in stock to fulfill my request
          ; otherwise reduce the number of items I would like to order from this trader
          let nr_of_products_to_order table:get stock_request product
          if nr_of_products_to_order > number_of_PPPs [
            set nr_of_products_to_order number_of_PPPs
          ]

            ; create an order for the trader who buys the product
            hatch 1 [
              set shape "PPP"
              set number_of_PPPs nr_of_products_to_order
              set dead_counter "none"
              set previous_owners lput owner [previous_owners] of myself
              set owner new_owner
              set selling_method [buying_method] of new_owner

              ; if the trader who buys the product sells its ware online, set the online? status of the order to true
              ifelse [online_offer?] of new_owner [
              set online? true
              set online_order_set_end_users (turtle-set online_order_set_end_users self)
            ][
              set online? false
            ]

              ; color the order according to the legal status of the product
              if progression_visualisation? [
                set_color_according_to_legal_status PPP_in_order
                move-to owner
              ]
            ask owner [set my_stock (turtle-set my_stock myself)]
            ]

            ; reduce my requested number of items
            ; if I bought all items I wanted of this product, remove the item from my shopping list
            table:put stock_request product table:get stock_request product - nr_of_products_to_order
            if table:get stock_request product <= 0 [
              table:remove stock_request product
              set requested_products remove product requested_products
            ]

            ; give money to the trader who sells the product to the buying trader
            ; the first trader to sell an NOP product gets more money for the product (as they know it's fake but sell it as a real product)

            ifelse [original_product?] of PPP_in_order or length previous_owners > 0  [
              ask owner [set profit_this_year profit_this_year + nr_of_products_to_order * profit_per_trader_to_trader_sale]][
              let sale_multiplier_NOP_product_trader_to_trader 0.4
              ask owner [set profit_this_year profit_this_year + round (nr_of_products_to_order * sale_multiplier_NOP_product_trader_to_trader * [sale_price_end_user] of [PPP_in_order] of myself + nr_of_products_to_order * profit_per_trader_to_trader_sale)]
            ]

            ; reduce the number of products in the original order (= the stock of the selling trader)
            set number_of_PPPs number_of_PPPs - nr_of_products_to_order

            ; if the seller runs out of stock of a product, tell them to buy
            if number_of_PPPs <= 0 [
              set dead_counter 5

              ask owner [
                set order_products? true
              ]

              if ticks > fixed_trust_period [
                let %_increase_trust_upon_full_sale 30
                change_trust_based_on_selling_method %_increase_trust_upon_full_sale
              ]
            ]
          ]
        ]
      ]
    ]

  ; reduce the trust in buying from traders for every type of requested product that couldn't be bought from a trader
  let %_reduction_trust_strategy_upon_no_product -10
  repeat table:length stock_request [
    adjust_trust %_reduction_trust_strategy_upon_no_product
  ]

  ; if some products were unavailable, ask the traders that the buying trader is connected to to order products
  if table:length stock_request > 0 [
    ask turtle-set my_traders [ set order_products? true]
  ]

end

To change_trust_based_on_selling_method [change_in_trust]

  ; change trust of the owner of the order based on the selling method via which the order was sold to the owner

  if selling_method = "trader" [ ask owner [ set trust_in_via_traders min list 100  (trust_in_via_traders + trust_in_via_traders * change_in_trust / 100) ]]
  if selling_method = "internet" [ ask owner [ set trust_in_via_internet min list 100 (trust_in_via_internet + trust_in_via_internet * change_in_trust / 100)]]
  if selling_method = "permit_holder" [ ask owner [ set trust_in_via_PH min list 100 (trust_in_via_PH + trust_in_via_PH * change_in_trust / 100)]]

end

To end_users_with_diseases_search_internet

  ; end-users find a product that is suitable for their crop and disease

  ; suitable online PPPs are narrowed down to products that are suitable for the crop and the disease in question
  ; pick one randomly
  let potential_products turtle-set online_order_set_end_users
  let product_to_be_used one-of potential_products with [[disease_PPP] of PPP_in_order = [disease_crop_end_user] of myself and [crop_type_PPP] of PPP_in_order = [crop_type_end_user] of myself and number_of_PPPs >= 1 ]

  ; if the package was sent to the end-user from outside the Netherlands, check if it has arrived
  let package_arrived? true
  if product_to_be_used != nobody and [owner] of product_to_be_used = "internet" [
    set package_arrived? send_package [PPP_in_order] of product_to_be_used]

  ; if the package has arrived, create a new order for the end-user
  let me self
  ifelse product_to_be_used != nobody and package_arrived? [

    ; if the original owner of the product is from outside the Netherlands, create a new order
    ifelse [owner] of product_to_be_used = "internet" [

      ask product_to_be_used [
        hatch 1 [
          set shape "PPP"
          set number_of_PPPs 0
          set previous_owners lput owner previous_owners
          set selling_method "internet"
          set owner me
          set online? false
          set dead_counter 5
          ask me [set my_stock (turtle-set my_stock myself)]
          ; color the order according to the legal status of the product
          if progression_visualisation? [
            set_color_according_to_legal_status PPP_in_order
          ]
        ]
      ]

      ; color the agent according to what it has bought
      let product [PPP_in_order] of product_to_be_used
      ask product [register_KPI]
      if progression_visualisation? [
        set_color_according_to_legal_status product
      ]
    ][
      ; if the original owner of the product is a Dutch trader, go into the trade_product procedure
      trade_product product_to_be_used
    ]

    ; let the end-user use the product
    use_product product_to_be_used
  ][

    ; if the end-user could not get a product via the internet, let them go into the end_user_no_cure procedure
    end_user_no_cure false
  ]

end

To inspect_random

  ; move to an inspection target and inspect there

  ; choose an inspection target randomly from the available targets (defined at set-up) that has not been inspected this year
  let agents_to_choose_from one-of inspection_list
  let to_be_assigned one-of agents_to_choose_from with [inspected_this_tick? = false]

  ; perform the inspection
  if to_be_assigned != nobody [
    set assigned_to to_be_assigned
    ask assigned_to [ set inspected_this_tick? true ]
    move-to assigned_to
    to_inspect
  ]

end

To to_inspect

  ; determine if the inspector finds an illegal PPP
  ; this is based on the number of PPPs that the inspectee has and the visibility of the illegalness and the testing method (visual inspection vs. profiling)

  ; count the number of PPPs of the inspectee
  let total_PPPs_of_inspectee sum [number_of_PPPs] of orders with [owner = [assigned_to] of myself]
  ; determine how many PPPs to inspect based on the user-defined percentage of PPPs to be inspected
  let nr_of_PPPs_inspected min list nr_of_PPPs_inspected_upon_visit_trader total_PPPs_of_inspectee

  ; the orders of end-users contain 0 PPPs, so if the inspectee is an end-user, count their orders as 1 PPP
  if [breed] of assigned_to = end_users [
    set total_PPPs_of_inspectee count orders with [owner = [assigned_to] of myself]
    set nr_of_PPPs_inspected min list nr_of_PPPs_inspected_upon_visit_end_user total_PPPs_of_inspectee
  ]

  let malpractice? false

  ; take samples of the PPPs
  repeat nr_of_PPPs_inspected [
    let sample one-of [my_stock] of assigned_to
    let PPP_sampled [PPP_in_order] of sample
    let PPP_caught? false

    ; if the PPP is illegal in the EU, it is always caught
    if [legal_in_EU?] of PPP_sampled = false [
      ask sample [catch_and_fine self]
      set malpractice? true
      set PPP_caught? true
    ]

    ; if the PPP is an NOP product, it will either be profiled or inspected
    ; this depends on the user-defined percentage of profiling performed by the inspector
    if [original_product?] of PPP_sampled = false [

      ; when profiling is used, the NOP product is always caught
      ifelse random 100 < %_profiling_used [
        ask sample [catch_and_fine self]
        set malpractice? true
        set PPP_caught? true
      ][
        ; if visual inspection is used, the inspector has a random chance of finding out that it is an NOP product
        ; this depends on the similarity to the original product of the PPP
        if random 100 > [similarity_to_original_product] of PPP_sampled [
          ask sample [catch_and_fine self]
          set malpractice? true
          set PPP_caught? true
        ]
      ]
    ]

    ; if the PPP was not caught, increase the trust of the owner in its selling method by a little
    if PPP_caught? = false [
      let %_increase_in_trust_upon_not_caught 2
      ask sample [ change_trust_based_on_selling_method %_increase_in_trust_upon_not_caught ]
    ]
  ]

  ; register the outcome of the inspection
  ifelse malpractice? [
    set company_observed_malpractice company_observed_malpractice + 1
  ][
    set company_observed_compliance company_observed_compliance + 1
  ]

  set assigned_to "none"
end

To catch_and_fine [order_with_offence]
  ; "give fine"
  ; update trust of buyer in the method by which they acquired the PPP
  let %_decrease_trust_upon_caught -50
  ask order_with_offence [ change_trust_based_on_selling_method %_decrease_trust_upon_caught ]

end

To set_color_according_to_legal_status [ product ]

  ; color the end-user / order by the legal status of the product it buys / contains
  if [legal_in_EU?] of product and [original_product?] of product [
    set color green
  ]
  if [legal_in_EU?] of product = false [
    set color 12
  ]
  if [original_product?] of product = false [
    set color 15
  ]

end

To-report discover_NOP [order_to_buy_from]

  ; check whether a NOP product is discoverd by the buyer

  let NOP_discovered? false

  ; check whether it is a NOP product
  let product [PPP_in_order] of order_to_buy_from
  if [original_product?] of product = false [

    ; check if the product is discovered
    if random 100 < [similarity_to_original_product] of product  [

      ; if a NOP product is discovered, reduce the trust of the buyer in the buying method
      set NOP_discovered? true
      let change_in_trust_upon_discovery_of_NOP_product -10
      adjust_trust change_in_trust_upon_discovery_of_NOP_product
    ]
  ]

  report NOP_discovered?

end
@#$#@#$#@
GRAPHICS-WINDOW
124
269
940
646
-1
-1
8.0
1
10
1
1
1
0
0
0
1
0
100
0
45
0
0
1
ticks
30.0

SWITCH
112
27
235
60
fixed-seed?
fixed-seed?
0
1
-1000

INPUTBOX
112
65
272
125
random_seed_value
1.350951681E9
1
0
Number

BUTTON
17
10
81
43
NIL
Setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
308
28
561
61
Nr_of_types_of_crops
Nr_of_types_of_crops
1
10
5.0
1
1
type(s) of crops
HORIZONTAL

TEXTBOX
114
10
264
28
Model settings\n
11
0.0
1

TEXTBOX
312
10
462
28
Setup variables - context\n
11
0.0
1

SLIDER
308
68
562
101
Nr_of_types_of_diseases
Nr_of_types_of_diseases
1
4
2.0
1
1
type(s) of diseases
HORIZONTAL

SLIDER
308
105
563
138
Nr_of_end_users
Nr_of_end_users
1
501
1.0
10
1
end-users
HORIZONTAL

SLIDER
568
106
785
139
%_always_comply_end_users
%_always_comply_end_users
0
100
50.0
1
1
%
HORIZONTAL

SLIDER
308
146
563
179
Nr_of_traders
Nr_of_traders
2
20
2.0
1
1
traders
HORIZONTAL

SLIDER
568
188
784
221
%_traders_end_user_only
%_traders_end_user_only
0
100
70.0
5
1
%
HORIZONTAL

SLIDER
569
148
785
181
%_always_comply_traders
%_always_comply_traders
0
100
65.0
1
1
%
HORIZONTAL

SLIDER
800
31
1060
64
Nr_of_inspectors
Nr_of_inspectors
0
10
0.0
1
1
inspectors
HORIZONTAL

SLIDER
311
228
703
261
%_coverage_of_disease_crop_combinations_legal_products
%_coverage_of_disease_crop_combinations_legal_products
0
100
25.0
5
1
% coverage
HORIZONTAL

TEXTBOX
1078
11
1228
39
Run variables - context\n\n
11
0.0
1

SLIDER
1077
29
1249
62
minimum_profit
minimum_profit
0
5000
300.0
100
1
NIL
HORIZONTAL

SLIDER
112
166
284
199
fixed_trust_period
fixed_trust_period
0
120
12.0
12
1
NIL
HORIZONTAL

BUTTON
17
155
98
188
NIL
unit_test
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
1077
67
1305
100
%_avg_chance_to_get_disease
%_avg_chance_to_get_disease
0
100
100.0
1
1
NIL
HORIZONTAL

BUTTON
16
45
79
78
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
16
82
93
115
go 100x
repeat 100 [ go ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
1318
37
1490
70
fine-to-profit_ratio
fine-to-profit_ratio
0
2
2.0
0.05
1
NIL
HORIZONTAL

SLIDER
1077
103
1293
136
inspection_chance_NL_border
inspection_chance_NL_border
0
100
10.0
1
1
NIL
HORIZONTAL

TEXTBOX
1319
10
1469
28
Run variables - NVWA\n
11
0.0
1

SLIDER
1317
73
1489
106
%_profiling_used
%_profiling_used
0
100
10.0
1
1
NIL
HORIZONTAL

SLIDER
1318
111
1556
144
nr_of_PPPs_inspected_upon_visit_trader
nr_of_PPPs_inspected_upon_visit_trader
1
50
10.0
1
1
NIL
HORIZONTAL

SWITCH
112
129
293
162
progression_visualisation?
progression_visualisation?
0
1
-1000

BUTTON
17
118
80
151
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
952
427
1431
616
Products arriving at end-user
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Legal products" 1.0 0 -13840069 true "" "plot legal_products_end_user"
"NOP products" 1.0 0 -2674135 true "" "plot NOP_products_end_user"
"Illegal in EU products" 1.0 0 -10873583 true "" "plot illegal_EU_products_end_user"

SLIDER
1318
148
1571
181
nr_of_PPPs_inspected_upon_visit_end_user
nr_of_PPPs_inspected_upon_visit_end_user
1
5
10.0
1
1
NIL
HORIZONTAL

PLOT
954
267
1154
417
count_orders
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count orders"

PLOT
1168
264
1368
414
mean ppps in order
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "carefully [plot mean [number_of_PPPs] of orders with [owner != \"internet\"]][plot 0]"

TEXTBOX
802
14
952
32
Setup variables - NVWA\n
11
0.0
1

TEXTBOX
52
306
202
325
Internet
15
15.0
1

TEXTBOX
56
376
206
395
Trader
15
25.0
1

TEXTBOX
32
449
182
468
Permit holder
15
55.0
1

TEXTBOX
59
528
209
547
Trader
15
25.0
1

TEXTBOX
50
606
200
625
Internet
15
15.0
1

TEXTBOX
18
268
168
287
Buying method
15
0.0
1

TEXTBOX
8
276
158
294
___________________
11
0.0
1

SLIDER
801
83
1059
116
inspect_end_users_EMA
inspect_end_users_EMA
0
1
1.0
1
1
NIL
HORIZONTAL

SLIDER
801
119
1058
152
inspect_end_user_only_traders_EMA
inspect_end_user_only_traders_EMA
0
1
0.0
1
1
NIL
HORIZONTAL

SLIDER
801
156
1058
189
inspect_trader_to_trader_only_traders_EMA
inspect_trader_to_trader_only_traders_EMA
0
1
0.0
1
1
NIL
HORIZONTAL

TEXTBOX
806
211
1072
281
Note: \nThese sliders indicate True/False switches but due to the EMA workbench have to be integers.
11
0.0
1

TEXTBOX
804
193
954
211
0 = False\n
11
0.0
1

TEXTBOX
1015
194
1165
212
1 = True
11
0.0
1

TEXTBOX
849
60
1061
110
-----------------------
20
0.0
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

end-user
false
0
Rectangle -16777216 true false 60 75 240 315
Circle -16777216 true false 96 6 108
Circle -7500403 true true 110 20 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

ppp
false
0
Rectangle -16777216 true false 90 75 195 330
Rectangle -7500403 true true 105 120 180 300
Rectangle -7500403 true true 120 75 165 120
Rectangle -7500403 false true 105 180 180 240
Rectangle -16777216 true false 105 165 180 225
Circle -7500403 true true 114 174 42
Circle -7500403 true true 150 180 30
Line -7500403 true 135 210 150 225
Line -7500403 true 135 210 135 225
Line -7500403 true 135 210 105 225
Line -7500403 true 120 165 135 180
Line -7500403 true 135 165 135 180
Line -7500403 true 150 165 135 180
Line -16777216 false 120 120 165 120

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
