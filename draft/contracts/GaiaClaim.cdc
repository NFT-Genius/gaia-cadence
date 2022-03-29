/** 

    GaiaClaim.cdc

    Description: Allows admins to mint redeemable "claim" NFTs, simple NFTs with initially hidden metadatas.

    This contract belongs to a set of "Drop" contracts that seek to orchestrate dynamic, type agnostic,
    NFT drops.
    
    It is important to note that: 
    - It is possible for admin to reveal the incorrect metadata for claims; therefore,
      it's the redeemer contract's responsibility to ensure that these malphormed claims cannot be redeemed.
    - At the contract level, claims can be  revealed at any time. The admin is responsible for ensuring
      that claims are revealed at the appropriate time (sometime after the claim reveal is requested).
    - This contract should be redeployed for every drop; otherwise, any "admin" could mint claims for any Redeemer to redeem. 
    - "dropID" in Mint event has no context at the contract level but might have some utility as a simple grouping mechanism

**/

import NonFungibleToken from "./core/NonFungibleToken.cdc"
import FungibleToken from "./core/FungibleToken.cdc"
import IGaiaClaim from "./IGaiaClaim.cdc"
import Crypto

pub contract GaiaClaim: NonFungibleToken, IGaiaClaim {

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let CollectionPrivatePath: PrivatePath
    pub let IGaiaClaimCollectionPublicPath: PublicPath
    pub let AdminStoragePath: StoragePath
    pub let AdminPrivatePath: PrivatePath
    pub let AuthorizerStoragePath: StoragePath

    pub event RequestedReveal(id: UInt64)
    pub event Revealed(id: UInt64) 
    pub event Mint(id: UInt64, commitHash: String, dropID: UInt64)
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event ContractInitialized()

    // centralized mapping of claim nft id to claim
    access(contract) let claims: @{UInt64: Claim}  

    // total supply of claims
    pub var totalSupply: UInt64

    pub fun borrowClaim(id: UInt64): &Claim? {
        return &self.claims[id] as &Claim
    }

    pub enum Status: UInt8 {
        pub case Sealed
        pub case Revealed
    }

    pub resource Claim {
        pub let commitHash: String
        pub var status: GaiaClaim.Status

        // fields to be "revealed" by admin
        pub var metadata: AnyStruct
        pub var salt: String?

        init(
            commitHash: String 
        ){
            self.commitHash = commitHash
            self.status = Status.Sealed
            self.salt = nil
            self.metadata = nil
        }

        access(contract) fun reveal(id:UInt64, metadata: AnyStruct, salt: String){
            assert(self.status == Status.Sealed, message: "claim status must be Sealed")
            self.metadata = metadata
            self.salt = salt
            self.status = Status.Revealed 
            emit Revealed(id: id)
        }
    }

    // NFT "claims" can be revealed and then redeemed in exchange for associated nfts.
    // 
    // Owners can "request a reveal" emitting a "RevealRequest" event. A backend service with Admin 
    // privileges listens for this event and submits a tx to reveal the claim metadata and salt.
    // This revealed metadata and salt helps a seperate "Redeemer" contract facilitate the
    // exchange of the claim for associated NFTs.
    pub resource NFT: NonFungibleToken.INFT, IGaiaClaim.IClaimToken {
        pub let id: UInt64
        pub let commitHash: String

        init(commitHash:String) {
            self.commitHash = commitHash

            GaiaClaim.totalSupply = GaiaClaim.totalSupply + 1
            self.id = GaiaClaim.totalSupply 
        }

        pub fun reveal(){
            GaiaClaim.requestReveal(id: self.id)
        }
    }

    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, IGaiaClaim.IGaiaClaimCollectionPublic {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }
        
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <- token
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @GaiaClaim.NFT
            let id: UInt64 = token.id
            let oldToken <- self.ownedNFTs[id] <- token
            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return &self.ownedNFTs[id] as &NonFungibleToken.NFT
        }

        pub fun borrowGaiaClaim(id: UInt64): &IGaiaClaim.NFT? {
            let nft<- self.ownedNFTs.remove(key: id) ?? panic("missing NFT")
            let token <- nft as! @GaiaClaim.NFT
            let ref = &token as &IGaiaClaim.NFT
            self.ownedNFTs[id] <-! token as! @GaiaClaim.NFT
            return ref
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    pub resource Authorizer {
        pub fun createNewAdmin(): @Admin {
            return <- create Admin()
        }
    }

    pub resource Admin: IGaiaClaim.IAdmin {
        pub fun mintClaim(hash: String, dropID: UInt64): @NonFungibleToken.NFT{
            // mint new claim nft
            let claimNFT <- create NFT(commitHash: hash) 

            // add claim to claim resource dictionary to preserve state
            let claim <- create Claim(commitHash: claimNFT.commitHash)
            GaiaClaim.claims[claimNFT.id] <-! claim

            emit Mint(
                id: claimNFT.id,
                commitHash: hash, 
                dropID: dropID
            )

            return <- claimNFT
        }

        pub fun revealClaim(id: UInt64, metadata: AnyStruct, salt: String) {
            var claim <- GaiaClaim.claims.remove(key:id) ?? panic("no such claim")
            claim.reveal(id: id, metadata: metadata, salt: salt)
            GaiaClaim.claims[id] <-! claim
        }
    }

    // emit an event that prompts the backend service with admin privileges to submit a tx revealing 
    // the claim metadata and salt
    access(contract) fun requestReveal(id: UInt64){
        let claim = GaiaClaim.borrowClaim(id: id) ?? panic("no such claim")
        assert(claim.status == GaiaClaim.Status.Sealed, message:"claim status must be Sealed")
        emit RequestedReveal(
            id: id
        )
    }

    init(){
        self.CollectionStoragePath = /storage/GaiaClaimCollection001
        self.CollectionPublicPath = /public/GaiaClaimCollection001
        self.CollectionPrivatePath = /private/GaiaClaimCollection001

        self.IGaiaClaimCollectionPublicPath = /public/IGaiaClaimCollection001

        self.AdminStoragePath = /storage/GaiaClaimAdmin
        self.AdminPrivatePath = /private/GaiaClaimAdmin

        self.AuthorizerStoragePath = /storage/GaiaClaimAuthorizer

        self.totalSupply = 0
        self.claims <- {} 

        // Create/Save a collection to receive Claims
        let collection <- self.createEmptyCollection() 
        self.account.save(<-collection, to: self.CollectionStoragePath)
        self.account.link<&Collection{NonFungibleToken.CollectionPublic}>(self.CollectionPublicPath, target: self.CollectionStoragePath)
        self.account.link<&Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(self.CollectionPrivatePath, target: self.CollectionStoragePath)
        self.account.link<&Collection{IGaiaClaim.IGaiaClaimCollectionPublic}>(self.IGaiaClaimCollectionPublicPath, target: self.CollectionStoragePath)

        // Create/Save an Authorizer to create new admins
        let authorizer <- create Authorizer()
        self.account.save(<-authorizer, to: self.AuthorizerStoragePath)

        // Create/Save an Admin to manually mint, reveal, and redeem claims
        let admin <- create Admin() 
        self.account.save(<-admin, to: self.AdminStoragePath)
        self.account.link<&Admin{IGaiaClaim.IAdmin}>(self.AdminPrivatePath, target: self.AdminStoragePath)

        emit ContractInitialized()
    }
}