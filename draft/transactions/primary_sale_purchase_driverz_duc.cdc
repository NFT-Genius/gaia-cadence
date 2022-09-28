import GaiaPrimarySale from 0xGaiaPrimarySale
import NonFungibleToken from 0xNonFungibleToken
import FungibleToken from 0xFungibleToken
import DriverzNFT from 0xDriverzNFT
import DapperUtilityCoin from 0xDapperUtilityCoin
import MetadataViews from 0xMetadataViews

transaction(
    marketplaceAddress: Address,
    primarySaleAddress: Address,
    primarySaleExternalID: String,
    assetIDs: [UInt64],
    priceType: String,
    expectedPrice: UFix64,
    sigExpiration: UInt64,
    sig: String
) {
    let paymentVault: @FungibleToken.Vault
    let primarySale: &{GaiaPrimarySale.PrimarySalePublic}
    let receiverCollection: &{NonFungibleToken.CollectionPublic}
    let purchaserAddress: Address
    let mainDapperUtilityCoinVault: &DapperUtilityCoin.Vault
    let balanceBeforeTransfer: UFix64

    prepare(dapper: AuthAccount, signer: AuthAccount) {
        assert(marketplaceAddress == 0x179b6b1cb6755e31, message: "Incorrect marketplace address")

        self.purchaserAddress = signer.address

        self.primarySale = getAccount(primarySaleAddress).getCapability<&{GaiaPrimarySale.PrimarySalePublic}>(GaiaPrimarySale.PrimarySalePublicPath).borrow()
            ?? panic("Cannot borrow primary sale")
        self.mainDapperUtilityCoinVault = dapper.borrow<&DapperUtilityCoin.Vault>(from: /storage/dapperUtilityCoinVault)
            ?? panic("Cannot borrow DapperUtilityCoin vault from account storage")
        self.balanceBeforeTransfer = self.mainDapperUtilityCoinVault.balance
        self.paymentVault <- self.mainDapperUtilityCoinVault.withdraw(amount: expectedPrice)

        // Make sure buyer has an NFT collection
        if signer.getCapability<&{NonFungibleToken.CollectionPublic}>(DriverzNFT.CollectionPublicPath).borrow() == nil {
            let collection <- DriverzNFT.createEmptyCollection() as! @DriverzNFT.Collection
            signer.save(<-collection, to: DriverzNFT.CollectionStoragePath)
            signer.link<&{NonFungibleToken.CollectionPublic, DriverzNFT.CollectionPublic, MetadataViews.ResolverCollection}>
                (DriverzNFT.CollectionPublicPath, target: DriverzNFT.CollectionStoragePath)
        }
        self.receiverCollection = signer.getCapability<&{NonFungibleToken.CollectionPublic}>(DriverzNFT.CollectionPublicPath).borrow()
            ?? panic("Cannot borrow NFT Collection")
    }

    execute {
        let data = GaiaPrimarySale.AdminSignedData(
            externalID: primarySaleExternalID,
            primarySaleAddress: primarySaleAddress,
            purchaserAddress: self.purchaserAddress,
            assetIDs: assetIDs,
            priceType: priceType,
            expiration: sigExpiration
        )

        let nfts <- self.primarySale.purchaseNFTs(
            payment: <- self.paymentVault,
            data: data,
            sig: sig
        )

        while nfts.length > 0 {
            let nft <- nfts.remove(at: 0)
            self.receiverCollection.deposit(token: <- nft)
        }
        assert(nfts.length == 0, message: "nfts(s) weren't deposited into collection")
        destroy nfts
    }

    // Check that all dapperUtilityCoin was routed back to Dapper
    post {
        self.mainDapperUtilityCoinVault.balance == self.balanceBeforeTransfer: "dapperUtilityCoin leakage"
    }
}
