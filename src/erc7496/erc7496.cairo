// @title DynamicTraits

// @dev Implementation of [ERC-7496](https://eips.ethereum.org/EIPS/eip-7496) Dynamic Traits.

// Requirements:
// - Overwrite `setTrait` with access role restriction.
// - Expose a function for `setTraitMetadataURI` with access role restriction if desired.
#[starknet::component]
mod ERC7496Component {
    use openzeppelin::introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use openzeppelin::introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin::introspection::src5::SRC5Component::SRC5;
    use openzeppelin::introspection::src5::SRC5Component;
    use cairo_erc_7496::erc7496::interface;

    #[storage]
    struct Storage {
        /// @dev A mapping of token ID to a mapping of trait key to trait value.
        ERC7496_traits: LegacyMap<(u256, felt252), felt252>,
        /// @dev An offchain string URI that points to a JSON file containing trait metadata.
        ERC7498_trait_metadata_uri: ByteArray,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event {
        TraitUpdated: TraitUpdated,
        TraitMetadataURIUpdated: TraitMetadataURIUpdated
    }

    /// Emitted when a dynamic trait is updated.
    #[derive(Drop, PartialEq, starknet::Event)]
    struct TraitUpdated {
        // #[key]
        trait_key: felt252,
        token_id: u256,
        trait_value: felt252
    }

    /// Emitted when metadata uri is updated.
    #[derive(Drop, PartialEq, starknet::Event)]
    struct TraitMetadataURIUpdated {}

    mod Errors {
        const TRAIT_VALUE_UNCHANGED: felt252 = 'ERC7496: trait value unchanged';
    }

    //
    // External
    //

    #[embeddable_as(ERC7496Impl)]
    impl ERC7496<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IERC7496<ComponentState<TContractState>> {
        // @notice Get the URI for the trait metadata
        fn get_trait_metadata_uri(self: @ComponentState<TContractState>) -> ByteArray {
            // Return the trait metadata URI.
            self.ERC7498_trait_metadata_uri.read()
        }
    }

    //
    // Internal
    //

    #[generate_trait]
    impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        /// Initializes the contract
        /// This should only be used inside the contract's constructor.
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(interface::IERC7496_ID);
        }

        // @notice Get the value of a trait for a given token ID.
        // @param tokenId The token ID to get the trait value for
        // @param traitKey The trait key to get the value of
        fn _get_trait_value(
            self: @ComponentState<TContractState>, token_id: u256, trait_key: felt252
        ) -> felt252 {
            // Return the trait value.
            self.ERC7496_traits.read((token_id, trait_key))
        }

        // @notice Get the values of traits for a given token ID.
        // @param tokenId The token ID to get the trait values for
        // @param traitKeys The trait keys to get the values of
        fn _get_trait_values(
            self: @ComponentState<TContractState>, token_id: u256, trait_keys: Span<felt252>
        ) -> Span<felt252> {
            let mut trait_values = array![];
            // Assign each trait value to the corresponding key.
            let mut index = 0;
            while index < trait_keys
                .len() {
                    trait_values
                        .append(self.ERC7496_traits.read((token_id, *trait_keys.at(index))));
                    index += 1;
                };
            trait_values.span()
        }

        // @notice Set the value of a trait for a given token ID.
        //         Reverts if the trait value is unchanged.
        // @dev    IMPORTANT: Override this method with access role restriction.
        // @param tokenId The token ID to set the trait value for
        // @param traitKey The trait key to set the value of
        // @param newValue The new trait value to set
        fn _set_trait(
            ref self: ComponentState<TContractState>,
            token_id: u256,
            trait_key: felt252,
            new_value: felt252
        ) {
            // Revert if the new value is the same as the existing value.
            let existing_value = self.ERC7496_traits.read((token_id, trait_key));
            assert(existing_value != new_value, Errors::TRAIT_VALUE_UNCHANGED);
            // Set the new trait value.
            self._set_trait_internal(token_id, trait_key, new_value);
            // Emit the event noting the update.
            self.emit(TraitUpdated { trait_key, token_id, trait_value: new_value });
        }

        // @notice Set the trait value (without emitting an event).
        // @param tokenId The token ID to set the trait value for
        // @param traitKey The trait key to set the value of
        // @param newValue The new trait value to set
        fn _set_trait_internal(
            ref self: ComponentState<TContractState>,
            token_id: u256,
            trait_key: felt252,
            new_value: felt252
        ) {
            // Set the new trait value.
            self.ERC7496_traits.write((token_id, trait_key), new_value);
        }

        // @notice Set the URI for the trait metadata.
        // @param uri The new URI to set.
        fn _set_trait_metadata_uri(ref self: ComponentState<TContractState>, uri: ByteArray) {
            // Set the new trait metadata URI.
            self.ERC7498_trait_metadata_uri.write(uri);
            // Emit the event noting the update.
            self.emit(TraitMetadataURIUpdated {});
        }
    }
}
