const express = require('express');
const bankVerify = require('./bankVerify');
const createWaiter = require('./createWaiter');

const app = express();
app.use(express.json());
app.use('/', bankVerify);
app.use('/', createWaiter);

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log(`Bank verify server on :${PORT}`));
