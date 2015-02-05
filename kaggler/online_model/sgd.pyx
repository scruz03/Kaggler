from __future__ import division
from itertools import izip
import numpy as np
import random

cimport cython
from libc.math cimport sqrt, fabs
from ..util cimport sigm
cimport numpy as np


np.import_array()


cdef class SGD:
    cdef unsigned int n
    cdef double a
    cdef double l1
    cdef double l2
    cdef double[:] w
    cdef double[:] c
    cdef bint interaction

    """Simple online learner using a hasing trick."""

    def __init__(self,
                 unsigned int n,
                 double a=0.01,
                 double l1=0.0,
                 double l2=0.0,
                 bint interaction=True):
        self.n = n      # # of features
        self.a = a      # learning rate
        self.l1 = l1
        self.l2 = l2

        # initialize weights and counts
        self.w = np.zeros((self.n,), dtype=np.float64)
        self.c = np.zeros((self.n,), dtype=np.float64)
        self.interaction = interaction

    def _indices(self, list x):
        cdef unsigned int index
        cdef int l
        cdef int i
        cdef int j

        yield 0

        for index in x:
            yield index

        if self.interaction:
            l = len(x)
            x = sorted(x)
            for i in xrange(l):
                for j in xrange(i + 1, l):
                    yield fabs(hash('{}_{}'.format(x[i], x[j]))) % self.n

    def get_x(self, list xs):
        """Apply hashing trick to a dictionary of {feature name: value}.

        Args:
            xs - a list of "idx:value"

        Returns:
            idx - a list of index of non-zero features
            val - a list of values of non-zero features
        """
        x = []
        for item in xs:
            index, _ = item.split(':')
            x.append(fabs(hash(index)) % self.n)

        return x

    def predict(self, list idx):
        """Predict for features.

        Args:
            idx - a list of index of non-zero features
            val - a list of values of non-zero features

        Returns:
            a prediction for input features
        """
        cdef int i
        cdef double wTx

        wTx = 0.
        for i in self._indices(idx):
            wTx += self.w[i]

        return sigm(wTx)

    def update(self, list idx, double p, double y):
        """Update the model.

        Args:
            idx - a list of index of non-zero features
            val - a list of values of non-zero features
            p - prediction of the model
            y - true target value

        Returns:
            updates model weights and counts
        """
        cdef int i
        cdef double e

        e = p - y
        for i in self._indices(idx):
            self.w[i] -= (e * self.a / (sqrt(self.c[i]) + 1) +
                          (self.l1 if self.w[i] >= 0. else -self.l1) +
                          self.l2 * fabs(self.w[i]))
            self.c[i] += fabs(e)