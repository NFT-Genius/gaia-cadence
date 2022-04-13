/** 

    GaiaDrop.cdc

    Description: Facilitates the exchange of Fungible Tokens for NFTs.

    This contract belongs to a set of "Drop" contracts that seek to orchestrate dynamic, type agnostic,
    NFT drops.
    
    It is important to note that: 
    - Only supports a single NFT type (no multi nft type bundles).
    - Paths assume that accounts will initialize a single drop only.

**/

import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe

pub contract GaiaDrop {

    pub let DropStoragePath: StoragePath
    pub let DropPublicPath: PublicPath
    pub let DropPrivatePath: PrivatePath

    pub event PurchasedNFT(nftType: Type, nftID: UInt64, purchaserAddress: Address)
    pub event ContractInitialized()

    // Data struct signed by account with specified "adminPublicKey."
    //
    // Permits accounts to purchase specific claims for some period of time.
    pub struct AdminSignedData {
        pub let dropAddress: Address
        pub let purchaserAddress: Address
        pub let nftIDs: [UInt64] 
        pub let expiration: UFix64 // unix timestamp

        init(dropAddress: Address, purchaserAddress: Address, nftIDs: [UInt64], expiration: UFix64){
            self.dropAddress = dropAddress
            self.purchaserAddress = purchaserAddress
            self.nftIDs = nftIDs
            self.expiration = expiration
        }

        pub fun toString(): String {
            var nftIDString = ""
            var i = 0
            for id in self.nftIDs {
                nftIDString = nftIDString.concat(id.toString())
                if i < self.nftIDs.length-1 {
                    nftIDString = nftIDString.concat(",")
                }
                i = i + 1
            }
            return self.dropAddress.toString().concat(":")
                .concat(self.purchaserAddress.toString()).concat(":")
                .concat(nftIDString).concat(":")
                .concat(self.expiration.toString())
        }
    }

    pub enum DropStatus: UInt8 {
        pub case PAUSED
        pub case OPEN
        pub case CLOSED
    }

    pub resource interface DropPublic {
        pub fun getDetails(): DropDetails
        pub fun getSupply(): Int
        pub fun getPrice(): UFix64
        pub fun purchaseNFTs(
            payment: @FungibleToken.Vault, 
            data: AdminSignedData, 
            sig: String
        ): @[NonFungibleToken.NFT]
    }

    pub resource interface DropPrivate {
        pub fun pause()
        pub fun open()
        pub fun setDetails(
            name: String,
            description: String,
            imageURI: String
        )
        pub fun setPrice(price: UFix64)
        pub fun setAdminPublicKey(adminPublicKey: String)
    }
    
    pub struct DropDetails {
        pub var name: String
        pub var description: String
        pub var imageURI: String

        init(
            name: String,
            description: String,
            imageURI: String
        ) {
            self.name = name
            self.description = description
            self.imageURI = imageURI
        }
    }

    pub resource Drop: DropPublic, DropPrivate {
        pub let size: Int
        pub let nftType: Type
        access(self) var status: DropStatus
        access(self) var price: UFix64

        // drop metadata
        access(self) var details: DropDetails

        access(self) let collectionCap: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
        access(self) let paymentReceiverCap: Capability<&{FungibleToken.Receiver}>

        // pub key used to verify signatures from a specified admin
        access(self) var adminPublicKey: String

        init(
            name: String,
            description: String,
            imageURI: String,
            nftType: Type,
            price: UFix64,
            collectionCap: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>, 
            paymentReceiverCap: Capability<&{FungibleToken.Receiver}>,
            adminPublicKey: String
        ) {
            self.details = DropDetails(
                name: name,
                description: description,
                imageURI: imageURI
            )
            self.nftType = nftType
            self.price = price
            self.size = collectionCap.borrow()!.getIDs().length
            self.status = DropStatus.PAUSED // drops are paused initially

            self.collectionCap = collectionCap
            self.paymentReceiverCap = paymentReceiverCap

            self.adminPublicKey = adminPublicKey
        }

        pub fun setDetails(
            name: String,
            description: String,
            imageURI: String
        ) {
            self.details = DropDetails(
                name: name,
                description: description,
                imageURI: imageURI
            )
        }

        pub fun getDetails(): DropDetails {
            return self.details
        }

        pub fun setPrice(price: UFix64) {
            self.price = price
        }

        pub fun getPrice(): UFix64 {
            return self.price
        }

        pub fun getSupply(): Int {
            return self.collectionCap.borrow()!.getIDs().length
        }

        pub fun setAdminPublicKey(adminPublicKey: String) {
            self.adminPublicKey = adminPublicKey
        }

        pub fun pause() {
            self.status = DropStatus.PAUSED
        }

        pub fun open() {
            pre {
                self.status != DropStatus.OPEN : "Drop is already open"
                self.status != DropStatus.CLOSED : "Cannot resume drop that is closed"
            }

            self.status = DropStatus.OPEN
        }

        // closed when supply runs out
        access(self) fun close() {
            self.status = DropStatus.CLOSED
        }

        access(self) fun verifyAdminSignedData(data: AdminSignedData, sig: String): Bool {
            let publicKey = PublicKey(
                publicKey: self.adminPublicKey.decodeHex(),
                signatureAlgorithm: SignatureAlgorithm.ECDSA_P256
            )

            return publicKey.verify(
                signature: sig.decodeHex(),
                signedData: data.toString().utf8,
                domainSeparationTag: "FLOW-V0.0-user",
                hashAlgorithm: HashAlgorithm.SHA3_256
            )
        }

        pub fun purchaseNFTs(
            payment: @FungibleToken.Vault, 
            data: AdminSignedData, 
            sig: String
        ): @[NonFungibleToken.NFT] {
            pre {
                self.status == DropStatus.OPEN : "drop is not open"
                data.nftIDs.length > 0: "must purchase at least one NFT"
                self.verifyAdminSignedData(data: data, sig: sig): "invalid admin signature for data"
                data.expiration >= getCurrentBlock().timestamp: "expired signature"
                payment.balance == self.price * UFix64(data.nftIDs.length): "payment vault does not contain requested price"
            }

            let receiver = self.paymentReceiverCap.borrow()!
            receiver.deposit(from: <- payment)

            let collection = self.collectionCap.borrow() ?? panic("cannot borrow collection")
            assert(collection.getIDs().length > 0, message: "drop is sold out")

            let nfts: @[NonFungibleToken.NFT] <- []
            for id in data.nftIDs {
                let nft <- collection.withdraw(withdrawID: id)
                emit PurchasedNFT(nftType: nft.getType(), nftID: nft.id, purchaserAddress: data.purchaserAddress)
                nfts.append(<-nft)
            }
            assert(nfts.length == data.nftIDs.length, message:"nft count mismatch")

            if self.getSupply() == 0 {
                self.close()
            }

            return <- nfts
        }
    }

    pub fun createDrop(
        name: String,
        description: String,
        imageURI: String,
        nftType: Type,
        price: UFix64,
        collectionCap: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>, 
        paymentReceiverCap: Capability<&{FungibleToken.Receiver}>,
        adminPublicKey: String
    ): @Drop {
        return <- create Drop(
            name: name,
            description: description,
            imageURI: imageURI,
            nftType: nftType,
            price: price,
            collectionCap: collectionCap,
            paymentReceiverCap: paymentReceiverCap,
            adminPublicKey: adminPublicKey
        )
    }

    init() {
        // default paths but not intended for multi drops on same acct
        self.DropStoragePath = /storage/GaiaDrop001
        self.DropPublicPath = /public/GaiaDrop001
        self.DropPrivatePath = /private/GaiaDrop001

        emit ContractInitialized()
    }
}