/** 

    IClaimNFT.cdc

    Description: NFTClaim contract interface.

    This contract belongs to a set of "Drop" contracts that seek to orchestrate dynamic, type agnostic,
    NFT drops.
    
**/

import NonFungibleToken from "./core/NonFungibleToken.cdc"
import FungibleToken from "./core/FungibleToken.cdc"

pub contract interface IClaimNFT {

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let CollectionPrivatePath: PrivatePath
    pub let IClaimNFTCollectionPublicPath: PublicPath
    pub let AdminStoragePath: StoragePath
    pub let AdminPrivatePath: PrivatePath
    
    pub event RequestedReveal(id: UInt64)
    pub event Revealed(id: UInt64) // todo
    pub event Mint(id: UInt64, commitHash: String, dropID: UInt64)
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event ContractInitialized()

    pub enum Status: UInt8 {
        pub case Sealed
        pub case Revealed
        pub case Redeemed
    }

    pub resource interface IAdmin {
        pub fun mintClaim(hash: String, dropID: UInt64): @NonFungibleToken.NFT
        pub fun revealClaim(id: UInt64, metadata: AnyStruct, salt: String)
    }

    pub resource Admin: IAdmin {
        pub fun mintClaim(hash: String, dropID: UInt64): @NonFungibleToken.NFT
        pub fun revealClaim(id: UInt64, metadata: AnyStruct, salt: String)
    }

    pub resource interface IClaim {
        pub let commitHash: String
        pub var status: Status 
        pub var metadata: AnyStruct
        pub var salt: String?
        access(contract) fun reveal(id: UInt64, metadata: AnyStruct, salt: String)
    } 

    pub resource interface IClaimToken {
        pub let commitHash: String
        pub fun reveal()
    }

    pub resource NFT: NonFungibleToken.INFT, IClaimToken {
        pub let id: UInt64
        pub let commitHash: String
        pub fun reveal()
    } 

    pub resource interface IClaimNFTCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowClaimNFT(id: UInt64): &IClaimNFT.NFT? {
            post {
                (result == nil) || (result!.id == id):
                    "Cannot borrow Claim reference: The ID of the returned reference is incorrect"
            }
        }
    }

    access(contract) fun requestReveal(id: UInt64)
}
 