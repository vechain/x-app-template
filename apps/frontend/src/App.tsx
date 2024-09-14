import { DAppKitProvider } from "@vechain/dapp-kit-react";
import { ChakraProvider, Container, Flex } from "@chakra-ui/react";
import { BrowserRouter as Router, Routes, Route } from "react-router-dom"; // Import React Router components
import {
  Dropzone,
  Footer,
  InfoCard,
  Instructions,
  Navbar,
  SubmissionModal,
} from "./components";
import { lightTheme } from "./theme";
import MealPlanning from "./components/MealPlanning";
import ViewSavedPlans from "./components/ViewSavedPlans";

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
        <Router>
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
              {/* Define your routes here */}
              <Routes>
                <Route path="/" element={<InfoCard />} />
                <Route path="/meal-planning" element={<MealPlanning />} />
                <Route path="/instructions" element={<Instructions />} />
                <Route path="/upload" element={<Dropzone />} />
                <Route path="/viewSavedPlans" element={<ViewSavedPlans />} />
              </Routes>
            </Container>
          </Flex>
          <Footer />

          {/* MODALS */}
          <SubmissionModal />
        </Router>
      </DAppKitProvider>
    </ChakraProvider>
  );
}

export default App;
