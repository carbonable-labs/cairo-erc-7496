const IERC7496_ID: felt252 = 0xaf332f3e;

#[starknet::interface]
trait IERC7496<TState> {
    // fn get_trait_value(self: @TState, token_id: u256, trait_key: felt252) -> felt252;
    // fn get_trait_values(self: @TState, token_id: u256, trait_keys: Span<felt252>) -> Span<felt252>;
    fn get_trait_metadata_uri(self: @TState) -> ByteArray;
    // fn set_trait(ref self: TState, token_id: u256, trait_key: felt252, new_value: felt252);
}
