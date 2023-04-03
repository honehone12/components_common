module components_common::royalty_utils {
    use std::option;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::object::Object;
    use aptos_token_objects::royalty::{Self, Royalty};
    
    public fun calc_royalty(value: u64, royalty: &Royalty): u64 {
        let numerator = royalty::numerator(royalty);
        let denominator = royalty::denominator(royalty);
        if (numerator == 0 || denominator == 0) {
            0
        } else {
            value * numerator / denominator
        }
    }

    public fun extract_royalty<TCoin>(base_coin: &mut Coin<TCoin>, royalty: &Royalty)
    : Coin<TCoin> {
        let stored_value = coin::value(base_coin);
        let royalty_value = calc_royalty(stored_value, royalty);
        coin::extract(base_coin, royalty_value)
    }

    public fun execute_royalty<T: key, TCoin>(base_coin: &mut Coin<TCoin>, object: Object<T>) {
        let royalty = royalty::get(object);
        if (option::is_some(&royalty)) {
            let royalty_raw = option::destroy_some(royalty);
            let royalty_coin = extract_royalty(base_coin, &royalty_raw);
            coin::deposit(royalty::payee_address(&royalty_raw), royalty_coin);
        }
    } 
}

