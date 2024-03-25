use starknet::ContractAddress;

#[starknet::interface]
trait IERC721DynamicTraits<TState> {
    fn mint(ref self: TState, to: ContractAddress, token_id: u256);
    fn get_trait_value(self: @TState, token_id: u256, trait_key: felt252) -> felt252;
    fn get_trait_values(self: @TState, token_id: u256, trait_keys: Span<felt252>) -> Span<felt252>;
    fn set_trait(ref self: TState, token_id: u256, trait_key: felt252, new_value: felt252);
    fn set_trait_metadata_uri(ref self: TState, uri: ByteArray);
}

#[starknet::interface]
trait IERC721DynamicTraitsMixin<TState> {
    // IERC721DynamicTraits
    fn mint(ref self: TState, to: ContractAddress, token_id: u256);
    // IERC7496
    fn get_trait_value(self: @TState, token_id: u256, trait_key: felt252) -> felt252;
    fn get_trait_values(self: @TState, token_id: u256, trait_keys: Span<felt252>) -> Span<felt252>;
    fn get_trait_metadata_uri(self: @TState) -> ByteArray;
    fn set_trait(ref self: TState, token_id: u256, trait_key: felt252, new_value: felt252);
    fn set_trait_metadata_uri(ref self: TState, uri: ByteArray);
    // IERC721
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn owner_of(self: @TState, token_id: u256) -> ContractAddress;
    fn safe_transfer_from(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    );
    fn transfer_from(ref self: TState, from: ContractAddress, to: ContractAddress, token_id: u256);
    fn approve(ref self: TState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TState, operator: ContractAddress, approved: bool);
    fn get_approved(self: @TState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @TState, owner: ContractAddress, operator: ContractAddress
    ) -> bool;
    // Ownable
    fn owner(self: @TState) -> ContractAddress;
    fn transfer_ownership(ref self: TState, new_owner: ContractAddress);
    fn renounce_ownership(ref self: TState);
    // ISRC5
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;
}

#[starknet::contract]
mod ERC721DynamicTraits {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc721::ERC721Component;
    use cairo_erc_7496::erc7496::erc7496::ERC7496Component;

    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: ERC7496Component, storage: erc7496, event: ERC7496Event);

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    // Ownable
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // ERC721
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    // ERC7496
    #[abi(embed_v0)]
    impl ERC7496Impl = ERC7496Component::ERC7496Impl<ContractState>;
    impl ERC7496InternalImpl = ERC7496Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        erc7496: ERC7496Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        ERC7496Event: ERC7496Component::Event,
    }

    /// Sets the token `name`, `symbol` and `base_uri`.
    #[constructor]
    fn constructor(
        ref self: ContractState, name: ByteArray, symbol: ByteArray, base_uri: ByteArray,
    ) {
        self.ownable.initializer(get_caller_address());
        self.erc721.initializer(name, symbol, base_uri);
        self.erc7496.initializer();
    }

    #[abi(embed_v0)]
    impl ERC721DynamicTraitsImpl of super::IERC721DynamicTraits<ContractState> {
        fn mint(ref self: ContractState, to: ContractAddress, token_id: u256) {
            self.ownable.assert_only_owner();
            self.erc721._mint(to, token_id);
        }

        fn get_trait_value(self: @ContractState, token_id: u256, trait_key: felt252) -> felt252 {
            assert(self.erc721._exists(token_id), ERC721Component::Errors::INVALID_TOKEN_ID);
            self.erc7496._get_trait_value(token_id, trait_key)
        }

        fn get_trait_values(
            self: @ContractState, token_id: u256, trait_keys: Span<felt252>
        ) -> Span<felt252> {
            assert(self.erc721._exists(token_id), ERC721Component::Errors::INVALID_TOKEN_ID);
            self.erc7496._get_trait_values(token_id, trait_keys)
        }

        fn set_trait(
            ref self: ContractState, token_id: u256, trait_key: felt252, new_value: felt252
        ) {
            self.ownable.assert_only_owner();
            assert(self.erc721._exists(token_id), ERC721Component::Errors::INVALID_TOKEN_ID);
            self.erc7496._set_trait(token_id, trait_key, new_value);
        }

        fn set_trait_metadata_uri(ref self: ContractState, uri: ByteArray) {
            self.ownable.assert_only_owner();
            self.erc7496._set_trait_metadata_uri(uri);
        }
    }
}
