import GaiaPrimarySale from 0x01ddf82c652e36ef

pub struct PurchaseData {
    pub let id: UInt64
    pub let name: String?
    pub let amount: UFix64
    pub let description: String?
    pub let imageURL: String?

    init(id: UInt64, name: String?, amount: UFix64, description: String?, imageURL: String?) {
        self.id = id
        self.name = name
        self.amount = amount
        self.description = description
        self.imageURL = imageURL
    }
}

pub fun main(primarySaleAddress: Address, assetIDs: [UInt64], expectedPrice: UFix64): PurchaseData {
    let account = getAccount(primarySaleAddress)

    let primarySaleRef = account
        .getCapability<&{GaiaPrimarySale.PrimarySalePublic}>(
            GaiaPrimarySale.PrimarySalePublicPath
        )
        .borrow()
        ?? panic("Could not borrow primary sale from address")

    let primarySaleDetails = primarySaleRef.getDetails()

    return PurchaseData(
        id: 0,
        name: primarySaleDetails.name,
        amount: expectedPrice,
        description: primarySaleDetails.description,
        imageURL: primarySaleDetails.imageURI,
    )
}
