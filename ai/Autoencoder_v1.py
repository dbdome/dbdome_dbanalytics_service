from torch import nn
from fastai.tabular.all import *

# Autoencoder model (simple MLP)
class AutoEncoder_v1(Module):
    def __init__(self, n_cont, emb_szs, hidden=[256,128,64]):
        self.embeds = nn.ModuleList([Embedding(ni, nf) for ni, nf in emb_szs])
        emb_sz = sum(e.embedding_dim for e in self.embeds)
        self.encoder = nn.Sequential(
            nn.Linear(emb_sz + n_cont, hidden[0]),
            nn.ReLU(),
            nn.Linear(hidden[0], hidden[1]),
            nn.ReLU(),
            nn.Linear(hidden[1], hidden[2]),
        )
        self.decoder = nn.Sequential(
            nn.Linear(hidden[2], hidden[1]),
            nn.ReLU(),
            nn.Linear(hidden[1], hidden[0]),
            nn.ReLU(),
            nn.Linear(hidden[0], emb_sz + n_cont),
        )
