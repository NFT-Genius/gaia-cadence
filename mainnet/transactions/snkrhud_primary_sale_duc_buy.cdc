import GaiaPrimarySale from 0x01ddf82c652e36ef
import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import SNKRHUDNFT from 0x80af1db15aa6535a
import DapperUtilityCoin from 0xead892083b3e2c6c

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
        assert(marketplaceAddress == 0x9eef2e4511390ce4, message: "Incorrect marketplace address")

        self.purchaserAddress = signer.address

        self.primarySale = getAccount(primarySaleAddress).getCapability<&{GaiaPrimarySale.PrimarySalePublic}>(GaiaPrimarySale.PrimarySalePublicPath).borrow()
            ?? panic("Cannot borrow primary sale")
        self.mainDapperUtilityCoinVault = dapper.borrow<&DapperUtilityCoin.Vault>(from: /storage/dapperUtilityCoinVault)
            ?? panic("Cannot borrow DapperUtilityCoin vault from account storage")
        self.balanceBeforeTransfer = self.mainDapperUtilityCoinVault.balance
        self.paymentVault <- self.mainDapperUtilityCoinVault.withdraw(amount: expectedPrice)

        // Make sure buyer has an NFT collection
        if signer.getCapability<&{NonFungibleToken.CollectionPublic}>(SNKRHUDNFT.CollectionPublicPath).borrow() == nil {
            let collection <- SNKRHUDNFT.createEmptyCollection() as! @SNKRHUDNFT.Collection
            signer.save(<-collection, to: SNKRHUDNFT.CollectionStoragePath)
            signer.link<&{NonFungibleToken.CollectionPublic, SNKRHUDNFT.CollectionPublic}>(SNKRHUDNFT.CollectionPublicPath, target: SNKRHUDNFT.CollectionStoragePath)
        }
        self.receiverCollection = signer.getCapability<&{NonFungibleToken.CollectionPublic}>(SNKRHUDNFT.CollectionPublicPath).borrow()
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
