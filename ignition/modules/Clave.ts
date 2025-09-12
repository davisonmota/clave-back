import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("ClaveModule", (m) => {

  // TODO: Set addresses for the contract arguments below
  const defaultAdmin = m.getAccount(0); // primeira conta do Hardhat
  const minter = m.getAccount(1); // segunda conta do Hardhat

  const clave = m.contract("Clave", [defaultAdmin, minter]);

  return { clave };
});
