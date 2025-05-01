import { ChakraProvider, Container, Flex } from "@chakra-ui/react";
import {
  Dropzone,
  Footer,
  InfoCard,
  Instructions,
  Marketplace,
  Navbar,
  SubmissionModal,
} from "./components";

import { DAppKitProvider } from "@vechain/dapp-kit-react";
import { lightTheme } from "./theme";

function App() {
  return (
    <ChakraProvider theme={lightTheme}>
      <DAppKitProvider
        usePersistence
        requireCertificate={false}
        genesis="test"
        nodeUrl="https://testnet.vechain.org/"
        logLevel={"DEBUG"}
      >
        <Navbar />
        <Flex flex={1}>
          <Container
            mt={{ base: 4, md: 10 }}
            maxW={"container.xl"}
            mb={{ base: 4, md: 10 }}
            display={"flex"}
            flex={1}
            alignItems={"center"}
            justifyContent={"flex-start"}
            flexDirection={"column"}
          >
            <InfoCard />
            <Instructions />
            <Dropzone />
            <Marketplace />
          </Container>
        </Flex>
        <Footer />

        {/* MODALS  */}
        <SubmissionModal />
      </DAppKitProvider>
    </ChakraProvider>
  );
}

export default App;
