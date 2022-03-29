/** 

    GaiaClaimRedeemer.cdc

    Description: Facilitates the exchange of Gaia Claim NFTs for NFTs.

    This contract belongs to a set of "Drop" contracts that seek to orchestrate dynamic, type agnostic,
    NFT drops.
    
    It is important to note that: 
    - This particular "FQTN" approach only works with preminted nfts.
    - Only supports a single NFT type (no multi nft type bundles).
    - Paths assume that accounts will initialize a single redeemer only.

**/

import NonFungibleToken from "./core/NonFungibleToken.cdc"
import FungibleToken from "./core/FungibleToken.cdc"
import GaiaClaim from "./GaiaClaim.cdc"

pub contract GaiaClaimRedeemer {

    pub let RedeemerStoragePath: StoragePath
    pub let RedeemerPublicPath: PublicPath
    pub let RedeemerPrivatePath: PrivatePath

    pub event RedeemedClaim(id: UInt64, fqtns: String)
    pub event ContractInitialized()

    pub resource interface RedeemerPublic {
        pub fun redeemClaim(claimNFT: @GaiaClaim.NFT): @[NonFungibleToken.NFT]
    }

    // fully qualified token name
    pub struct FQTN {
        pub let address: Address
        pub let contractName: String
        pub let declarationName: String // potentially redundant, will almost always be "NFT" 
        pub let id: UInt64

        pub fun hashString(): String {
            // address string is 16 characters long with 0x as prefix (for 8 bytes in hex)
            // example: ,f3fcd2c1a78f5ee.ContractName.NFT.12
            let c = "A."
            var a = ""
            let addrStr = self.address.toString()
            if addrStr.length < 18 {
                let padding = 18 - addrStr.length
                let p = "0"
                var i = 0
                a = addrStr.slice(from: 2, upTo: addrStr.length)
                while i < padding {
                    a = p.concat(a)
                    i = i + 1
                }
            } else {
                a = addrStr.slice(from: 2, upTo: 18)
            }
            var str = c.concat(a).concat(".")
                .concat(self.contractName).concat(".")
                .concat(self.declarationName).concat(".")
                .concat(self.id.toString())
            return str
        } 

        pub fun typeIdentifer(): String {
            return "A."
                .concat(self.address.toString()).concat(".")
                .concat(self.contractName).concat(".")
                .concat(self.declarationName)
        }

        init(address: Address, contractName: String, declarationName: String, id: UInt64) {
            self.address = address
            self.contractName = contractName
            self.declarationName = declarationName
            self.id = id
        }
    }

    pub resource Redeemer: RedeemerPublic {
        access(self) let nftType: Type
        access(self) let collectionCap: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>

        // verify that fqtns and salt matches initial commit hash
        access(self) fun verifyClaim(fqtns: [FQTN], salt: String, commitHash: String): String {
            var salt = salt
            var nftString = fqtns[0].hashString()
            var i = 1

            while i < fqtns.length {
                let s = fqtns[i].hashString()
                nftString = nftString.concat(",").concat(s)
                i = i+1
            }
            let hashString = salt.concat(",").concat(nftString)
            let hash = HashAlgorithm.SHA3_256.hash(hashString.utf8)

            assert(commitHash == String.encodeHex(hash), message: "commitHash was not verified")

            return nftString
        }

        // exchange claim for associated NFTs
        pub fun redeemClaim(claimNFT: @GaiaClaim.NFT): @[NonFungibleToken.NFT]{
            let collection = self.collectionCap.borrow() ?? panic("cannot borrow collection")
            let claim = GaiaClaim.borrowClaim(id: claimNFT.id) ?? panic("missing associated claim data")
            assert(claim.status == GaiaClaim.Status.Revealed, message: "claim must be revealed before redemption")

            let fqtns = claim.metadata as? [FQTN] ?? panic("claim metadata type mismatch")
            let fqtnsString = self.verifyClaim(fqtns: fqtns, salt: claim.salt!, commitHash: claim.commitHash) 

            let nfts: @[NonFungibleToken.NFT] <- []
            for fqtn in fqtns {
                assert(self.nftType.identifier != fqtn.typeIdentifer(), message: "fqtn nft type mismatch, this contract does not support multi-type drops")
                let nft <- collection.withdraw(withdrawID: fqtn.id) 
                nfts.append(<-nft)
            }
            assert(nfts.length > 0, message:"no nfts redeemed")
            assert(nfts.length == fqtns.length, message:"nft redeem count mismatch")

            emit RedeemedClaim(id: claimNFT.id, fqtns: fqtnsString)
            
            destroy claimNFT

            return <- nfts
        }

        init(
            nftType: Type,
            collectionCap: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
        ) {
            self.nftType = nftType
            self.collectionCap = collectionCap
        }
    }

    pub fun createRedeemer(
        nftType: Type,
        collectionCap: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
    ): @Redeemer {
        return <- create Redeemer(
            nftType: nftType,
            collectionCap: collectionCap
        )
    }

    init(){
        // default paths but not intended for multi redeemers on same acct
        self.RedeemerStoragePath = /storage/GaiaClaimRedeemer001
        self.RedeemerPublicPath = /public/GaiaClaimRedeemer001
        self.RedeemerPrivatePath = /private/GaiaClaimRedeemer001

        emit ContractInitialized()
    }

}